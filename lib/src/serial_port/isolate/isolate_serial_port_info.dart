import 'dart:typed_data';

import '../../../flutter_nesigner_sdk.dart';

// This port only use to hold the serial port info, can't handle data transfer.
class IsolateSerialPortInfo extends SerialPort {
  final int? _busNumber;

  final String? _description;

  final int? _deviceNumber;

  final bool _isOpen;

  final String? _macAddress;

  final String? _manufacturer;

  final String? _name;

  final int? _productId;

  final String? _productName;

  final String? _serialNumber;

  final int _transport;

  final int? _vendorId;

  IsolateSerialPortInfo(
      this._busNumber,
      this._description,
      this._deviceNumber,
      this._isOpen,
      this._macAddress,
      this._manufacturer,
      this._name,
      this._productId,
      this._productName,
      this._serialNumber,
      this._transport,
      this._vendorId);

  @override
  int? get busNumber => _busNumber;

  @override
  String? get description => _description;

  @override
  int? get deviceNumber => _deviceNumber;

  @override
  bool get isOpen => _isOpen;

  @override
  String? get macAddress => _macAddress;

  @override
  String? get manufacturer => _manufacturer;

  @override
  String? get name => _name;

  @override
  int? get productId => _productId;

  @override
  String? get productName => _productName;

  @override
  String? get serialNumber => _serialNumber;

  @override
  int get transport => _transport;

  @override
  int? get vendorId => _vendorId;

  @override
  Future<bool> close() {
    throw UnimplementedError();
  }

  @override
  Future<int> directWrite(Uint8List bytes) {
    throw UnimplementedError();
  }

  @override
  Future<bool> open() {
    throw UnimplementedError();
  }

  @override
  void receiveData(void Function(Uint8List event) onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {}
}
