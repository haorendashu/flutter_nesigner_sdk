import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_nesigner_sdk/flutter_nesigner_sdk.dart';
import 'package:flutter_nesigner_sdk/src/usb/usb_isolate_transport_worker.dart';

class UsbIsolateTransport extends Transport {
  Isolate? isolate;

  ReceivePort? receivePort;

  SendPort? sendPort;

  @override
  Future<bool> close() async {
    if (isolate != null) {
      isolate!.kill();
      return true;
    }

    return false;
  }

  @override
  bool get isOpen => isolate != null;

  Function(Uint8List event)? _onData;

  @override
  void listen(void Function(Uint8List event) onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    _onData = onData;
  }

  @override
  Future<bool> open() async {
    receivePort = ReceivePort("UsbIsolateTransport");
    receivePort!.listen((data) {
      if (data is SendPort) {
        sendPort = data;
      } else if (data is Uint8List) {
        if (_onData != null) {
          _onData!(data);
        }
      }
    });

    var rootIsolateToken = RootIsolateToken.instance!;

    isolate = await Isolate.spawn(
      UsbIsolateTransportWorker.newAndRunWorker,
      UsbIsolateTransportWorkerConfig(
        rootIsolateToken: rootIsolateToken,
        sendPort: receivePort!.sendPort,
        vid: UsbTransport.VID,
        pid: UsbTransport.PID,
        configNum: UsbTransport.CONFIG_NUM,
        interfaceNum: UsbTransport.INTERFACE_NUM,
        outEndPoint: UsbTransport.OUT_ENDPOINT,
        inEndPoint: UsbTransport.IN_ENDPOINT,
      ),
    );

    return true;
  }

  @override
  int write(Uint8List bytes) {
    if (sendPort != null) {
      sendPort!.send(bytes);
      return bytes.length;
    }

    return 0;
  }
}
