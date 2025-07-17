import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_nesigner_sdk/src/serial_port/isolate/isolate_serial_port_action.dart';
import 'package:flutter_nesigner_sdk/src/serial_port/isolate/isolate_serial_port_worker_config.dart';

import '../../../flutter_nesigner_sdk.dart';
import 'package:libserialport/libserialport.dart' as ls;

import 'isolate_serial_port_info.dart';
import 'isolate_serial_port_worker.dart';

class IsolateSerialPort extends SerialPort {
  static List<IsolateSerialPort> getNesignerPorts() {
    List<IsolateSerialPort> nesignerPorts = [];
    var ports = ls.SerialPort.availablePorts;
    for (var port in ports) {
      try {
        IsolateSerialPort nesignerPort = IsolateSerialPort(port);
        if (nesignerPort.productId == 0x3434 && nesignerPort.vendorId == 0x2323) {
          nesignerPorts.add(nesignerPort);
        }
      } catch (e) {
        print("Error checking port $port: $e");
        continue; // Skip this port if there's an error
      }
    }

    return nesignerPorts;
  }

  String serialPortName;

  late ls.SerialPort sp;

  IsolateSerialPort(this.serialPortName) {
    sp = ls.SerialPort(serialPortName);
  }

  Isolate? isolate;

  ReceivePort? receivePort;

  SendPort? sendPort;

  Completer<bool>? _openComplete;

  bool _connectStatus = false;

  @override
  Future<bool> open() async {
    receivePort = ReceivePort("IsolateSerialPort");
    _openComplete = Completer<bool>();
    receivePort!.listen((data) {
      if (data is SendPort) {
        // print("main receive SendPort!");
        sendPort = data;
      } else if (data is Uint8List) {
        if (_onData != null) {
          _onData!(data);
        }
      } else if (data is List && data.isNotEmpty && data[0] is String) {
        var action = data[0];
        if (action == IsolateSerialPortAction.OPEN_SUCCESS) {
          // print("main receive open success!");
          if (_openComplete != null) {
            _openComplete!.complete(true);
            _openComplete = null;
          }
          _connectStatus = true;
        } else if (action == IsolateSerialPortAction.OPEN_FAIL) {
          // print("main receive open fail!");
          if (_openComplete != null) {
            _openComplete!.complete(false);
            _openComplete = null;
          }
          _connectStatus = false;
        } else if (action == IsolateSerialPortAction.WRITE_COMPLETE) {
          // print("main receive write complete!");
        }
      }
    });

    var rootIsolateToken = RootIsolateToken.instance!;
    isolate = await Isolate.spawn(
      IsolateSerialPortWorker.newAndRunWorker,
      IsolateSerialPortWorkerConfig(
        rootIsolateToken: rootIsolateToken,
        sendPort: receivePort!.sendPort,
        serialPortName: serialPortName,
      ),
    );

    return _openComplete!.future.timeout(const Duration(seconds: 10));
  }

  @override
  Future<bool> close() async {
    _connectStatus = false;

    if (sendPort != null) {
      sendPort!.send([IsolateSerialPortAction.CLOSE]);
      await Future.delayed(const Duration(milliseconds: 200));
      sendPort = null;
    }

    if (receivePort != null) {
      receivePort!.close();
      receivePort = null;
    }

    if (isolate != null) {
      isolate!.kill();
    }

    return true;
  }

  // send full data to worker and write it splitly in worker.
  @override
  Future<int> write(Uint8List bytes) async {
    return await directWrite(bytes);
  }

  @override
  Future<int> directWrite(Uint8List bytes) async {
    if (sendPort != null) {
      sendPort!.send(bytes);
      return bytes.length;
    }

    return -1;
  }

  Function(Uint8List event)? _onData;

  @override
  void receiveData(void Function(Uint8List event) onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    _onData = onData;
  }

  // IsolateSerialPortInfo? info;

  // @override
  // int? get busNumber => info?.busNumber;

  // @override
  // String? get description => info?.description;

  // @override
  // int? get deviceNumber => info?.deviceNumber;

  // @override
  // bool get isOpen => info == null ? false : info!.isOpen;

  // @override
  // String? get macAddress => info?.macAddress;

  // @override
  // String? get manufacturer => info?.manufacturer;

  // @override
  // String? get name => info?.name;

  // @override
  // int? get productId => info?.productId;

  // @override
  // String? get productName => info?.productName;

  // @override
  // String? get serialNumber => info?.serialNumber;

  // @override
  // int get transport =>
  //     info != null ? info!.transport : ls.SerialPortTransport.native;

  // @override
  // int? get vendorId => info?.vendorId;

  @override
  bool get isOpen => _connectStatus;

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
