import 'dart:async';

import 'package:squadron/squadron.dart';

// ignore: unused_import
import 'data.dart';
import 'data_marshaler_ext.dart' as ext_d;
import 'generated/data_service.activator.g.dart';

part 'generated/data_service.worker.g.dart';

@SquadronService()
class DataService {
  @squadronMethod
  FutureOr<Data> doSomething(Data input) =>
      Data(input.a + 1, !input.b, '(was $input)');
}
