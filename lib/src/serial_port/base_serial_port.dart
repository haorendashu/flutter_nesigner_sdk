import 'dart:async';
import 'dart:io';

import 'dart:typed_data';

import 'serial_port.dart';
import 'package:libserialport/libserialport.dart' as ls;

class BaseSerialPort extends SerialPort {
  static List<String> get availablePorts {
    if (Platform.isIOS) {
      return [];
    }

    return ls.SerialPort.availablePorts;
  }

  late ls.SerialPort sp;

  BaseSerialPort(String name) {
    sp = ls.SerialPort(name);
    sp.config = ls.SerialPortConfig()
      ..baudRate = 115200
      ..bits = 8
      ..stopBits = 1
      ..parity = ls.SerialPortParity.none;
  }

  @override
  Future<bool> open() async {
    clearBuffer();
    return sp.open(mode: ls.SerialPortMode.readWrite);
  }

  @override
  Future<bool> close() async {
    if (_reader != null) {
      try {
        _reader!.close();
      } catch (e) {}
    }
    sp.close();
    sp.dispose();
    clearBuffer();
    return true;
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

  @override
  void receiveData(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    _reader = ls.SerialPortReader(sp);
    _reader!.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  ls.SerialPortReader? _reader;

  @override
  int write(Uint8List bytes) {
    return sp.write(bytes);
  }
}
