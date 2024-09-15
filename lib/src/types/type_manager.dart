import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';
import 'package:squadron_builder/src/marshalers/marshaler.dart';
import 'package:squadron_builder/src/readers/annotations_reader.dart';

import '../marshalers/converters.dart';
import 'extensions.dart';
import 'known_type.dart';
import 'managed_type.dart';

class TypeManager {
  TypeManager(LibraryElement library) : _prefixes = library.prefixes {
    final provider = library.typeProvider;

    final squadron = library.libraryImports
        .where((import) => import.isFromPackage('package:squadron/'))
        .firstOrNull;

    if (squadron == null) {
      throw InvalidGenerationSourceError('Missing import of Squadron library.');
    }

    squadronAlias = squadron.prefix?.element.name ?? '';
    squadronPrefix = squadronAlias.isEmpty ? '' : '$squadronAlias.';

    converters.squadronAlias = squadronAlias;

    final squadronPckUri = 'package:squadron/';
    entryPointType = KnownType(squadronPckUri, 'EntryPoint', squadron);
    channelType = KnownType(squadronPckUri, 'Channel', squadron);
    workerServiceType = KnownType(squadronPckUri, 'WorkerService', squadron);
    workerType = KnownType(squadronPckUri, 'Worker', squadron);
    workerPoolType = KnownType(squadronPckUri, 'WorkerPool', squadron);
    workerRequestType = KnownType(squadronPckUri, 'WorkerRequest', squadron);
    workerStatType = KnownType(squadronPckUri, 'WorkerStat', squadron);
    perfCounterType = KnownType(squadronPckUri, 'PerfCounter', squadron);
    concurrencySettingsType =
        KnownType(squadronPckUri, 'ConcurrencySettings', squadron);
    exceptionManagerType =
        KnownType(squadronPckUri, 'ExceptionManager', squadron);
    platformThreadHookType =
        KnownType(squadronPckUri, 'PlatformThreadHook', squadron);
    squadronMarshalerType =
        KnownType(squadronPckUri, 'SquadronMarshaler', squadron);
    commandHandlerType = KnownType(squadronPckUri, 'CommandHandler', squadron);
    taskType = KnownType(squadronPckUri, 'Task', squadron);
    valueTaskType = KnownType(squadronPckUri, 'ValueTask', squadron);
    streamTaskType = KnownType(squadronPckUri, 'StreamTask', squadron);

    cancelationTokenType = _getImportedType(
        library, 'package:cancelation_token/', 'CancelationToken');
    loggerType = _getImportedType(library, 'package:logger/', 'Logger');
    typedDataType = _getImportedType(library, 'dart:typed_data', 'TypedData');

    listType = handleDartType(provider.listType(provider.dynamicType));
  }

  KnownType _getImportedType(
      LibraryElement library, String pckUri, String baseName) {
    final import = library.libraryImports
        .where((i) => i.isFromPackage(pckUri))
        .firstOrNull;
    return KnownType(pckUri, 'TypedData', import);
  }

  final converters = Converters();

  final List<PrefixElement> _prefixes;

  late final String squadronPrefix;
  late final String squadronAlias;

  late final ManagedType listType;

  late final KnownType entryPointType;
  late final KnownType channelType;
  late final KnownType workerServiceType;
  late final KnownType workerType;
  late final KnownType workerPoolType;
  late final KnownType workerRequestType;
  late final KnownType workerStatType;
  late final KnownType perfCounterType;
  late final KnownType exceptionManagerType;
  late final KnownType concurrencySettingsType;
  late final KnownType platformThreadHookType;
  late final KnownType squadronMarshalerType;
  late final KnownType commandHandlerType;
  late final KnownType taskType;
  late final KnownType valueTaskType;
  late final KnownType streamTaskType;

  late final KnownType cancelationTokenType;
  late final KnownType loggerType;
  late final KnownType typedDataType;

  final _cache = <DartType, ManagedType>{};

  ManagedType handleDartType(DartType type) {
    var managedType = _cache[type];
    if (managedType != null) {
      return managedType;
    }

    if (type is RecordType) {
      managedType = ManagedType.record(type, this);
    } else {
      String? prefix;

      final typeLib = type.element?.library;
      if (typeLib != null) {
        prefix = _prefixes
            .where((p) => p.imports.any((i) => i.importedLibrary == typeLib))
            .firstOrNull
            ?.name;
      }

      managedType = ManagedType(prefix, type, this);
      managedType.setMarshaler(this);
    }

    _cache[type] = managedType;
    return managedType;
  }

  bool _isMarshaler(DartObject obj) =>
      obj.type?.isA(squadronMarshalerType) ?? false;

  Marshaler? getExplicitMarshaler(Element? element) {
    final marshaler =
        element?.declaration?.getAnnotations().where(_isMarshaler).firstOrNull;
    if (marshaler == null) return null;
    final type = marshaler.toTypeValue() ?? marshaler.type;
    final baseMarshaler = type?.implementedTypes(squadronMarshalerType);
    if (baseMarshaler == null || baseMarshaler.isEmpty) {
      throw InvalidGenerationSourceError(
          'Invalid marshaler for $element: $marshaler');
    }
    return Marshaler.explicit(marshaler, handleDartType(baseMarshaler.single));
  }
}
