import 'serial_port.dart';
import 'package:libserialport/libserialport.dart' as ls;

class BaseSerialPort extends SerialPort {
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
  bool open() {
    return sp.open(mode: ls.SerialPortMode.readWrite);
  }

  @override
  bool close() {
    return sp.close();
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
