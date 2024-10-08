import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:squadron/squadron.dart';

import 'assets/worker_assets.dart';
import 'build_step_events.dart';
import 'readers/squadron_service_reader.dart';
import 'types/type_manager.dart';
import 'version.dart';

/// Alias for a code formatting function.
typedef Formatter = String Function(String source);

/// Code generator for Squadron workers.
class WorkerGenerator extends GeneratorForAnnotation<SquadronService> {
  WorkerGenerator({Formatter? formatOutput, bool withFinalizers = false})
      : _formatOutput = formatOutput ?? _noFormatting,
        _withFinalizers = withFinalizers {
    _buildStepEventStream.stream.listen(_process);
  }

  late final String _header = '''
      // GENERATED CODE - DO NOT MODIFY BY HAND
      
      // **************************************************************************
      // Generator: $this
      // **************************************************************************
      ''';

  final bool _withFinalizers;
  final Formatter _formatOutput;

  final _buildStepEventStream = StreamController<BuildStepEvent>();

  final _results = <BuildStep, BuildStepCodeEvent>{};
  final _buildStepToTypeManager = <BuildStep, TypeManager>{};

  @override
  Future<String> generate(LibraryReader library, BuildStep buildStep) async {
    try {
      final existingTypeManager = _buildStepToTypeManager[buildStep];
      // get a typemanager for the library
      if (existingTypeManager != null) {
        throw UnsupportedError('WorkerGenerator.generate() is not reentrant!');
      }
      final typeManager = TypeManager(library.element);
      _buildStepToTypeManager[buildStep] = typeManager;
      // generate code
      final result = StringBuffer();
      result.writeln(await super.generate(library, buildStep));
      result.writeln(_formatOutput(typeManager.converters.code));

      // success, trigger code generation for additional assets associated to this libreay
      _buildStepEventStream.add(BuildStepDoneEvent(buildStep));

      return result.toString();
    } catch (ex, st) {
      log.severe(ex);
      log.severe(st);
      rethrow;
    }
  }

  @override
  Stream<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) async* {
    final classElt = element;
    if (classElt is! ClassElement) return;

    final typeManager = _buildStepToTypeManager[buildStep];
    if (typeManager == null) {
      throw StateError('TypeManager not found for build step $buildStep');
    }

    final service = SquadronServiceReader.load(classElt, typeManager);
    if (service == null) return;

    typeManager.initialize();

    if (_withFinalizers) {
      typeManager.checkImportsFor(
          'To generate fnalization code, your library must import the following:',
          [
            typeManager.TReleasable,
            typeManager.TCancelationToken,
            typeManager.TLogger,
            typeManager.TFutureOr
          ]);
    }

    final assets = WorkerAssets(buildStep, service);

    final codeEvent = BuildStepCodeEvent(buildStep, classElt);
    assets.generateVmCode(codeEvent);
    assets.generateWebCode(codeEvent);
    assets.generateCrossPlatformCode(codeEvent);
    assets.generateActivatorCode(codeEvent);
    _buildStepEventStream.add(codeEvent);

    yield* assets.generateWorkerAndPool(_withFinalizers);
  }

  void _process(BuildStepEvent event) {
    if (event is BuildStepCodeEvent) {
      _registerAssetCode(event);
    } else if (event is BuildStepDoneEvent) {
      _writeAssetCode(event);
    } else {
      log.warning('Discarding unknown build step event ${event.runtimeType}');
    }
  }

  void _registerAssetCode(BuildStepCodeEvent newResult) {
    final result = _results[newResult.buildStep];
    if (result == null) {
      // first result: register
      _results[newResult.buildStep] = newResult;
    } else {
      // merge additional results as they come through
      result.mergeWith(newResult);
    }
  }

  void _writeAssetCode(BuildStepDoneEvent done) {
    final result = _results[done.buildStep];
    if (result != null) {
      _results.remove(done.buildStep);
      final insertHeader = [_header].followedBy;
      for (var asset in result.assets) {
        var code = insertHeader(result.getCode(asset)).join('\n\n');
        try {
          code = _formatOutput(code);
        } catch (ex) {
          log.severe(
              'An exception occurred while formatting code for ${asset.uri}: $ex');
        }
        result.buildStep.writeAsString(asset, code);
      }
    }
  }

  @override
  String toString() => '$runtimeType $version';
}

String _noFormatting(String source) => source;
