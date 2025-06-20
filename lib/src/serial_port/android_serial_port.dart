import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_nesigner_sdk/flutter_nesigner_sdk.dart';
import 'package:usb_serial/usb_serial.dart';

class AndroidSerialPort extends SerialPort {
  UsbDevice device;

  UsbPort? _usbPort;

  AndroidSerialPort(this.device);

  static Future<List<SerialPort>> getNesignerPorts() async {
    if (!Platform.isAndroid) {
      return [];
    }

    List<SerialPort> nesignerPorts = [];
    var devices = await UsbSerial.listDevices();
    for (var device in devices) {
      if (device.pid == 0x3434 && device.vid == 0x2323) {
        SerialPort nesignerPort = AndroidSerialPort(device);
        nesignerPorts.add(nesignerPort);
      }
    }
    return nesignerPorts;
  }

  @override
  Future<bool> open() async {
    var port = await device.create();
    if (port != null) {
      var openResult = await port.open();
      if (openResult) {
        _usbPort = port;
      }
      return openResult;
    }

    return false;
  }

  @override
  int? get busNumber => -1;

  @override
  Future<bool> close() async {
    if (_usbPort != null) {
      await _usbPort!.close();
      _usbPort = null;
    }
    return true;
  }

  @override
  String? get description => device.toString();

  @override
  int? get deviceNumber => device.deviceId;

  @override
  bool get isOpen => _usbPort != null ? true : false;

  @override
  String? get macAddress => "Unimplemented";

  @override
  String? get manufacturer => device.manufacturerName;

  @override
  String? get name => device.deviceName;

  @override
  int? get productId => device.pid;

  @override
  String? get productName => device.productName;

  @override
  void receiveData(void Function(Uint8List event) onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    if (_usbPort != null && _usbPort!.inputStream != null) {
      _usbPort!.inputStream!.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
    }
  }

  @override
  String? get serialNumber => device.serial;

  @override
  int get transport => SerialPortTransport.usb;

  @override
  int? get vendorId => device.vid;

  @override
  Future<int> write(Uint8List bytes) async {
    if (_usbPort == null) {
      return 0;
    }

    await _usbPort!.write(bytes);
    return bytes.length;
  }
}
