import 'dart:isolate';

import 'package:flutter/services.dart';

class IsolateSerialPortWorkerConfig {
  RootIsolateToken rootIsolateToken;
  SendPort sendPort;
  String serialPortName;

  IsolateSerialPortWorkerConfig({
    required this.rootIsolateToken,
    required this.sendPort,
    required this.serialPortName,
  });
}
