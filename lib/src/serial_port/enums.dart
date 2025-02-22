abstract class SerialPortTransport {
  /// Native platform serial port. @since 0.1.1
  static const int native = 0;

  /// USB serial port adapter. @since 0.1.1
  static const int usb = 1;

  /// Bluetooth serial port adapter. @since 0.1.1
  static const int bluetooth = 2;
}
