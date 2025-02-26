import 'dart:async';
import 'dart:typed_data';

abstract class Transport {
  /// Opens the serial port.
  bool open();

  /// Closes the serial port.
  bool close();

  /// Gets whether the serial port is open.
  bool get isOpen;

  StreamSubscription<Uint8List> listen(void onData(Uint8List event)?,
      {Function? onError, void onDone()?, bool? cancelOnError});

  /// Write data to the serial port.
  /// Returns the amount of bytes written.
  int write(Uint8List bytes);
}
