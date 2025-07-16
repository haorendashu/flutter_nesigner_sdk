import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_nesigner_sdk/src/serial_port/isolate/isolate_serial_port_action.dart';
import 'package:flutter_nesigner_sdk/src/serial_port/isolate/isolate_serial_port_worker_config.dart';
import 'package:libserialport/libserialport.dart' as ls;

import '../../../flutter_nesigner_sdk.dart';
import '../serial_port.dart';

class IsolateSerialPortWorker extends SerialPort {
  IsolateSerialPortWorkerConfig config;

  late ls.SerialPort sp;

  IsolateSerialPortWorker(this.config);

  static void newAndRunWorker(IsolateSerialPortWorkerConfig config) {
    var worker = IsolateSerialPortWorker(config);
    worker.sp = ls.SerialPort(config.serialPortName);
    worker.run();
  }

  Future<bool> openAndReceiveData() async {
    var openResult = await open();

    if (openResult) {
      receiveData((Uint8List data) {
        // receive data from serial port
        config.sendPort.send(data);
      });
    }

    return openResult;
  }

  Future<void> run() async {
    var openResult = await openAndReceiveData();

    ReceivePort workerReceivePort = ReceivePort("IsolateSerialPortWorker");
    config.sendPort.send(workerReceivePort.sendPort);

    workerReceivePort.listen(workerReceiveMessage);
    if (openResult) {
      config.sendPort.send([IsolateSerialPortAction.OPEN_SUCCESS]);
    } else {
      config.sendPort.send([IsolateSerialPortAction.OPEN_FAIL]);
    }

    // print("IsolateSerialPortWorker run");
  }

  /// worker receive message from ui
  Future<void> workerReceiveMessage(data) async {
    // print("worker receive data!");
    if (data is Uint8List) {
      var wrote = await write(data);
      // print("dataLength ${data.length} wrote $wrote");
      config.sendPort.send([IsolateSerialPortAction.WRITE_COMPLETE, wrote]);
    } else if (data is List && data.isNotEmpty && data[0] is String) {
      // print(data);
      // receive action
      var action = data[0];
      if (action == IsolateSerialPortAction.CLOSE) {
        close();
      }
    }
  }

  @override
  void receiveData(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    _reader = ls.SerialPortReader(sp);
    _reader!.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  ls.SerialPortReader? _reader;

  @override
  Future<int> directWrite(Uint8List bytes) async {
    var wrote = sp.write(bytes);
    // This line will cause macos not work, so we comment it out.
    // sp.flush(ls.SerialPortBuffer.output);
    return wrote;
  }

  @override
  Future<bool> close() async {
    if (_reader != null) {
      try {
        _reader!.close();
      } catch (e) {}
    }
    sp.close();
    clearBuffer();
    print("IsolateSerialPort close");
    return true;
  }

  @override
  Future<bool> open() async {
    clearBuffer();
    var openResult = sp.open(mode: ls.SerialPortMode.readWrite);
    if (openResult) {
      sp.config = ls.SerialPortConfig()
        ..baudRate = 115200
        ..bits = 8
        ..stopBits = 1
        ..parity = ls.SerialPortParity.none
        ..setFlowControl(ls.SerialPortFlowControl.none);
    }
    return openResult;
  }

  @override
  bool get isOpen => sp.isOpen;

  @override
  String? get name => sp.name;

  @override
  String? get description => sp.description;

  @override
  int get transport => sp.transport;

  @override
  int? get busNumber => sp.busNumber;

  @override
  int? get deviceNumber => sp.deviceNumber;

  @override
  int? get vendorId => sp.vendorId;

  @override
  int? get productId => sp.productId;

  @override
  String? get manufacturer => sp.manufacturer;

  @override
  String? get productName => sp.productName;

  @override
  String? get serialNumber => sp.serialNumber;

  @override
  String? get macAddress => sp.macAddress;
}
