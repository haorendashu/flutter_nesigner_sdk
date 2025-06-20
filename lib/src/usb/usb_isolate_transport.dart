// import 'dart:async';
// import 'dart:isolate';
// import 'dart:typed_data';

// import 'package:flutter/services.dart';
// import 'package:flutter_nesigner_sdk/flutter_nesigner_sdk.dart';
// import 'package:flutter_nesigner_sdk/src/usb/usb_isolate_transport_worker.dart';

// class UsbIsolateTransport extends Transport {
//   Isolate? isolate;

//   ReceivePort? receivePort;

//   SendPort? sendPort;

//   @override
//   Future<bool> close() async {
//     if (sendPort != null) {
//       sendPort!.send([UsbIsolateTransportAction.CLOSE]);
//       await Future.delayed(const Duration(milliseconds: 2000));
//       sendPort = null;
//     }

//     if (receivePort != null) {
//       receivePort!.close();
//       receivePort = null;
//     }

//     if (isolate != null) {
//       isolate!.kill();
//     }

//     return true;
//   }

//   @override
//   bool get isOpen => isolate != null;

//   Function(Uint8List event)? _onData;

//   @override
//   void listen(void Function(Uint8List event) onData,
//       {Function? onError, void Function()? onDone, bool? cancelOnError}) {
//     _onData = onData;
//   }

//   Completer<bool>? _openComplete;

//   @override
//   Future<bool> open() async {
//     receivePort = ReceivePort("UsbIsolateTransport");
//     receivePort!.listen((data) {
//       if (data is SendPort) {
//         sendPort = data;
//       } else if (data is Uint8List) {
//         if (_onData != null) {
//           _onData!(data);
//         }
//       } else if (data is List && data.isNotEmpty && data[0] is String) {
//         var action = data[0];
//         if (_openComplete != null) {
//           if (action == UsbIsolateTransportAction.OPEN_SUCCESS) {
//             _openComplete!.complete(true);
//             _openComplete = null;
//           } else if (action == UsbIsolateTransportAction.OPEN_FAIL) {
//             _openComplete!.complete(false);
//             _openComplete = null;
//           }
//         }
//       }
//     });

//     var rootIsolateToken = RootIsolateToken.instance!;

//     isolate = await Isolate.spawn(
//       UsbIsolateTransportWorker.newAndRunWorker,
//       UsbIsolateTransportWorkerConfig(
//         rootIsolateToken: rootIsolateToken,
//         sendPort: receivePort!.sendPort,
//         vid: UsbTransport.VID,
//         pid: UsbTransport.PID,
//         configNum: UsbTransport.CONFIG_NUM,
//         interfaceNum: UsbTransport.INTERFACE_NUM,
//         outEndPoint: UsbTransport.OUT_ENDPOINT,
//         inEndPoint: UsbTransport.IN_ENDPOINT,
//         macosArchIsArm: UsbTransport.macosArchIsArm,
//       ),
//     );

//     _openComplete = Completer<bool>();

//     return _openComplete!.future.timeout(const Duration(seconds: 10));
//   }

//   @override
//   Future<int> write(Uint8List bytes) async {
//     if (sendPort != null) {
//       sendPort!.send(bytes);
//       return bytes.length;
//     }

//     return 0;
//   }
// }

// class UsbIsolateTransportAction {
//   static const OPEN_SUCCESS = "openSuccess";
//   static const OPEN_FAIL = "openFail";
//   static const CLOSE = "close";
//   static const CLOSE_SUCCESS = "closeSuccess";
// }
