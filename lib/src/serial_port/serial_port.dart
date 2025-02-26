import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/scheduler.dart';
import 'package:libserialport/libserialport.dart' as ls;

import '../transport/transport.dart';

/// SerialPort
///
/// libserialport doesn't support IOS. So wrap it and hope that someone can make an IOS one.
abstract class SerialPort extends Transport {
  /// Gets the name of the port.
  ///
  /// The name returned is whatever is normally used to refer to a port on the
  /// current operating system; e.g. for Windows it will usually be a "COMn"
  /// device name, and for Unix it will be a device path beginning with "/dev/".
  String? get name;

  /// Gets the description of the port, for presenting to end users.
  String? get description;

  /// Gets the transport type used by the port.
  ///
  /// See also:
  /// - [SerialPortTransport]
  int get transport;

  /// Gets the USB bus number of a USB serial adapter port.
  int? get busNumber;

  /// Gets the USB device number of a USB serial adapter port.
  int? get deviceNumber;

  /// Gets the USB vendor ID of a USB serial adapter port.
  int? get vendorId;

  /// Gets the USB Product ID of a USB serial adapter port.
  int? get productId;

  /// Get the USB manufacturer of a USB serial adapter port.
  String? get manufacturer;

  /// Gets the USB product name of a USB serial adapter port.
  String? get productName;

  /// Gets the USB serial number of a USB serial adapter port.
  String? get serialNumber;

  /// Gets the MAC address of a Bluetooth serial adapter port.
  String? get macAddress;
}
