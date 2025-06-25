import 'dart:async';
import 'dart:typed_data';

abstract class Transport {
  // 2+16+2+32+16+4=72
  static const PREFIX_LENGTH = 72;

  static const CRC_LENGTH = 2;

  /// Opens the serial port.
  Future<bool> open();

  /// Closes the serial port.
  Future<bool> close();

  /// Gets whether the serial port is open.
  bool get isOpen;

  void listen(void onData(Uint8List event),
      {Function? onError, void onDone()?, bool? cancelOnError});

  /// Write data to the serial port.
  /// Returns the amount of bytes written.
  /// This method may split the data into multiple packets if necessary.
  Future<int> write(Uint8List bytes);

  /// Direct write bytes.
  Future<int> directWrite(Uint8List bytes);
}
