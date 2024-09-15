import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';
import 'package:squadron/squadron.dart';

import '../marshalers/marshaler.dart';
import '../types/managed_type.dart';
import '../types/type_manager.dart';
import 'annotations_reader.dart';
import 'squadron_parameters.dart';

part 'squadron_method_reader.dart';

/// Reader for non-service methods implemented in a SquadronService
class DartMethodReader {
  DartMethodReader._(MethodElement method, this.typeManager)
      : name = method.name,
        returnType = typeManager.handleDartType(method.returnType);

  final String name;
  final TypeManager typeManager;

  final ManagedType returnType;

  bool get isStream => returnType.dartType?.isDartAsyncStream ?? false;
  bool get isFuture => returnType.dartType?.isDartAsyncFuture ?? false;
  bool get isFutureOr => returnType.dartType?.isDartAsyncFutureOr ?? false;

  final typeParameters = <String>[];
  late final parameters = SquadronParameters(typeManager);

  void _init(MethodElement method) {
    if (method.typeParameters.isNotEmpty) {
      typeParameters.addAll(method.typeParameters.map((e) => e.toString()));
    }

    for (var n = 0; n < method.parameters.length; n++) {
      parameters.register(method.parameters[n], null);
    }
  }

  static DartMethodReader? load(MethodElement method, TypeManager typeManager) {
    if (method.name == 'toString' || method.name == 'noSuchMethod') {
      // base Dart methods -- ignore
      return null;
    }
    final reader = AnnotationReader<SquadronMethod>(method);
    DartMethodReader m;
    if (reader.isEmpty || method.name.startsWith('_')) {
      // private method or no SquadronMethod annotation
      m = DartMethodReader._(method, typeManager);
    } else {
      final inspectRequest = reader.isSet('inspectRequest');
      final inspectResponse = reader.isSet('inspectResponse');
      m = SquadronMethodReader._(
          method, inspectRequest, inspectResponse, typeManager);
    }
    m._init(method);
    return m;
  }

  String get declaration => typeParameters.isEmpty
      ? '$returnType $name($parameters)'
      : '$returnType $name<${typeParameters.join(', ')}>($parameters)';
}
