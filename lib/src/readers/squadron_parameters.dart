import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';

import '../marshalers/marshaler.dart';
import '../types/extensions.dart';
import '../types/managed_type.dart';
import '../types/type_manager.dart';
import 'squadron_parameter.dart';

class SquadronParameters {
  SquadronParameters(this.typeManager);

  SquadronParameters clone() {
    final params = SquadronParameters(typeManager);
    params._params.addAll(_params);
    params._cancelationToken = _cancelationToken;
    params._hasPositionalParameters = _hasPositionalParameters;
    params._hasNamedParameters = _hasNamedParameters;
    params._hasOptionalParameters = _hasOptionalParameters;
    return params;
  }

  final TypeManager typeManager;

  final _params = <SquadronParameter>[];

  String? _cancelationToken;
  String? get cancelationToken => _cancelationToken;

  bool _hasPositionalParameters = false;
  bool _hasNamedParameters = false;
  bool _hasOptionalParameters = false;

  static bool _all(SquadronParameter p) => true;
  Iterable<SquadronParameter> get all => _params.where(_all);

  static bool _positional(SquadronParameter p) => !p.isNamed && !p.isOptional;
  Iterable<SquadronParameter> get positional => _params.where(_positional);

  static bool _optional(SquadronParameter p) => p.isOptional;
  Iterable<SquadronParameter> get optional => _params.where(_optional);

  static bool _named(SquadronParameter p) => p.isNamed;
  Iterable<SquadronParameter> get named => _params.where(_named);

  bool _checkCancelationToken(ParameterElement param) {
    if (param.type.implementedTypes(typeManager.cancelationTokenType).isEmpty) {
      // not a cancelation token
      return false;
    }
    if (_cancelationToken != null) {
      throw InvalidGenerationSourceError(
          'Multiple cancelation tokens may not be passed to service methods '
          '($_cancelationToken, ${param.name}). You should use a '
          'CompositeCancelationToken instead.');
    } else {
      _cancelationToken = param.name;
      return true;
    }
  }

  SquadronParameter register(ParameterElement param, Marshaler? marshaler) {
    final isToken = _checkCancelationToken(param);
    int serIdx = -1;
    if (!isToken) {
      serIdx = _params.length - (_cancelationToken != null ? 1 : 0);
    }
    return _register(
        SquadronParameter.from(param, isToken, marshaler, serIdx, typeManager));
  }

  SquadronParameter addOptional(String name, ManagedType managedType) =>
      _register(SquadronParameter.opt(
          name, managedType, _hasNamedParameters || !_hasOptionalParameters));

  SquadronParameter _register(SquadronParameter param) {
    if ((param.isNamed && _hasOptionalParameters) ||
        (param.isOptional && _hasNamedParameters)) {
      throw InvalidGenerationSourceError(
          'Cannot register both named and optional parameters. Parameter name: '
          '${param.name}');
    }

    if (param.isNamed) {
      _hasNamedParameters = true;
    } else if (param.isOptional) {
      _hasOptionalParameters = true;
    } else {
      _hasPositionalParameters = true;
    }

    _params.add(param);
    return param;
  }

  String arguments() => _params.map((p) => p.argument()).join(', ');

  String serialize() => _params
      // cancelation token is passed separately when invoking the worker
      .where((p) => !p.isCancelationToken)
      .map((p) => p.serialized())
      .join(', ');

  String deserialize(String jsonObj) =>
      _params.map((p) => p.deserialized(jsonObj)).join(', ');

  @override
  String toString() {
    if (_hasPositionalParameters) {
      if (_hasOptionalParameters) {
        return '${positional.join(', ')}, [${optional.join(', ')}]';
      } else if (_hasNamedParameters) {
        return '${positional.join(', ')}, {${named.join(', ')}}';
      } else {
        return positional.join(', ');
      }
    } else if (_hasOptionalParameters) {
      return '[${optional.join(', ')}]';
    } else if (_hasNamedParameters) {
      return '{${named.join(', ')}}';
    } else {
      return '';
    }
  }

  String toStringNoFields() {
    if (_hasPositionalParameters) {
      if (_hasOptionalParameters) {
        return '${positional.toStringNoField().join(', ')}, [${optional.toStringNoField().join(', ')}]';
      } else if (_hasNamedParameters) {
        return '${positional.toStringNoField().join(', ')}, {${named.toStringNoField().join(', ')}}';
      } else {
        return positional.toStringNoField().join(', ');
      }
    } else if (_hasOptionalParameters) {
      return '[${optional.toStringNoField().join(', ')}]';
    } else if (_hasNamedParameters) {
      return '{${named.toStringNoField().join(', ')}}';
    } else {
      return '';
    }
  }
}

extension _ParamExt on Iterable<SquadronParameter> {
  Iterable<String> toStringNoField() => map((p) => p.toStringNoField());
}
