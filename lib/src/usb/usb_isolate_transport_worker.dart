import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_nesigner_sdk/flutter_nesigner_sdk.dart';
import 'package:libusb/libusb64.dart';
import 'package:ffi/ffi.dart';
import 'package:async/async.dart';

class UsbIsolateTransportWorkerConfig {
  RootIsolateToken rootIsolateToken;
  SendPort sendPort;
  int vid;
  int pid;
  int configNum;
  int interfaceNum;
  int outEndPoint;
  int inEndPoint;
  UsbIsolateTransportWorkerConfig({
    required this.rootIsolateToken,
    required this.sendPort,
    required this.vid,
    required this.pid,
    required this.configNum,
    required this.interfaceNum,
    required this.outEndPoint,
    required this.inEndPoint,
  });
}

class UsbIsolateTransportWorker {
  UsbIsolateTransportWorkerConfig config;

  UsbIsolateTransportWorker(this.config);

  static void newAndRunWorker(UsbIsolateTransportWorkerConfig config) {
    var worker = UsbIsolateTransportWorker(config);
    worker.run();
  }

  Libusb? libusb;

  Pointer<libusb_device_handle>? deviceHandlePtr;

  StreamController<Uint8List>? streamController;
  StreamQueue<Uint8List>? queue;

  void run() {
    BackgroundIsolateBinaryMessenger.ensureInitialized(config.rootIsolateToken);

    libusb = Libusb(UsbTransport.loadLibrary());
    var initResult = libusb!.libusb_init(nullptr);
    if (initResult < 0) {
      return;
    }
    print("init success!");

    var deviceListPtr = calloc<Pointer<Pointer<libusb_device>>>();
    listdevs(deviceListPtr);
    calloc.free(deviceListPtr);

    deviceHandlePtr = libusb!
        .libusb_open_device_with_vid_pid(nullptr, config.vid, config.pid);
    if (deviceHandlePtr!.address <= 0) {
      print("libusb_open_device_with_vid_pid fail");
      return;
    }

    var result =
        libusb!.libusb_claim_interface(deviceHandlePtr!, config.interfaceNum);
    if (result != libusb_error.LIBUSB_SUCCESS) {
      print("libusb_claim_interface error $result");
      return;
    }

    ReceivePort workerReceivePort = ReceivePort("UsbIsolateTransportWorker");
    config.sendPort.send(workerReceivePort.sendPort);

    streamController = StreamController<Uint8List>();
    queue = StreamQueue<Uint8List>(streamController!.stream);
    waitForMessage();

    workerReceivePort.listen(workerReceiveMessage);

    config.sendPort.send([UsbIsolateTransportAction.OPEN_SUCCESS]);
    print("libusb open success!");
  }

  void waitForMessage() async {
    while (_running) {
      var message = await queue!.next;
      handleMessage(message);
    }
  }

  void workerReceiveMessage(data) {
    if (data is Uint8List) {
      if (streamController != null) {
        streamController!.add(data);
      }
    } else if (data is List && data.isNotEmpty && data[0] is String) {
      // receive action
      var action = data[0];
      if (action == UsbIsolateTransportAction.CLOSE) {
        doClose();
      }
    }
  }

  bool _running = true;

  void doClose() {
    _running = false;

    if (streamController != null) {
      streamController!.close();
      streamController = null;
    }
    if (queue != null) {
      queue!.cancel();
      queue = null;
    }
    if (deviceHandlePtr != null) {
      libusb!.libusb_release_interface(deviceHandlePtr!, config.interfaceNum);
      libusb!.libusb_close(deviceHandlePtr!);
      deviceHandlePtr = null;
    }
    if (libusb != null) {
      libusb!.libusb_exit(nullptr);
      libusb = null;
    }

    print("libusb exit success!");
  }

  void handleMessage(data) {
    if (data is Uint8List) {
      // send
      var dataPointer = UsbTransport.convertUint8ListToPointer(data);
      var actualLength = calloc<Int>(8);
      var sendResult = libusb!.libusb_bulk_transfer(deviceHandlePtr!,
          config.outEndPoint, dataPointer, data.length, actualLength, 1000);
      print("sendResult $sendResult");

      if (actualLength.value == data.length) {
        // send complete, begin to read
        doRead();
      }
    }
  }

  Uint8List _receiveBuffer = Uint8List(0);

  void doRead() {
    var bufferLength = 1024 * 4;
    var buffer = calloc<UnsignedChar>(1024 * 4);
    var actualLength = calloc<Int>(8);

    while (true) {
      // print("begin to receive data");
      var readResult = libusb!.libusb_bulk_transfer(deviceHandlePtr!,
          config.inEndPoint, buffer, bufferLength, actualLength, 30000);
      if (readResult == libusb_error.LIBUSB_SUCCESS) {
        // read success!
        var readedLength = actualLength.value;
        var data = UsbTransport.convertPointerToUint8List(buffer, readedLength);

        _receiveBuffer = Uint8List.fromList([..._receiveBuffer, ...data]);
        if (_receiveBuffer.length < Transport.PREFIX_LENGTH) continue;

        // print("receive data");
        // print(_receiveBuffer);

        // 解析长度头（最后4字节的包头）
        final headerBytes = _receiveBuffer.sublist(
            Transport.PREFIX_LENGTH - 4, Transport.PREFIX_LENGTH);
        final totalLen =
            ByteData.sublistView(headerBytes).getUint32(0, Endian.big);

        // 计算完整帧长度
        final fullFrameLength = Transport.PREFIX_LENGTH + totalLen;

        // print("buffer length ${_receiveBuffer.length} data length ${totalLen}");

        // 检查是否收到完整帧
        if (_receiveBuffer.length < fullFrameLength) continue;

        // 提取完整帧数据
        final frameData = _receiveBuffer.sublist(0, fullFrameLength);
        _receiveBuffer = _receiveBuffer.sublist(fullFrameLength);

        config.sendPort.send(frameData);
        break;
      } else {
        // read fail! The call will be timeout by himself.
        print("read fail!");
        _receiveBuffer = Uint8List(0);
        break;
      }
    }

    malloc.free(buffer);
    malloc.free(actualLength);
  }

  void listdevs(Pointer<Pointer<Pointer<libusb_device>>> deviceListPtr) {
    var count = libusb!.libusb_get_device_list(nullptr, deviceListPtr);
    if (count < 0) {
      return;
    }

    var deviceList = deviceListPtr.value;
    printDevs(deviceList);
    libusb!.libusb_free_device_list(deviceList, 1);
  }

  void printDevs(Pointer<Pointer<libusb_device>> deviceList) {
    var descPtr = calloc<libusb_device_descriptor>();
    var path = calloc<Uint8>(8);

    for (var i = 0; deviceList[i] != nullptr; i++) {
      var dev = deviceList[i];
      var result = libusb!.libusb_get_device_descriptor(dev, descPtr);
      if (result < 0) continue;

      var desc = descPtr.ref;
      var idVendor = desc.idVendor.toRadixString(16).padLeft(4, '0');
      var idProduct = desc.idProduct.toRadixString(16).padLeft(4, '0');
      var bus = libusb!.libusb_get_bus_number(dev).toRadixString(16);
      var addr = libusb!.libusb_get_device_address(dev).toRadixString(16);
      print(
          '$idVendor:$idProduct (bus $bus, device $addr) vid:${desc.idVendor} pid:${desc.idProduct}');

      var portCount = libusb!.libusb_get_port_numbers(dev, path, 8);
      if (portCount > 0) {
        // var hexList = path.asTypedList(portCount).map((e) => hex.encode([e]));
        // print(' path: ${hexList.join('.')}');
      }
    }

    calloc.free(descPtr);
    calloc.free(path);
  }
}
