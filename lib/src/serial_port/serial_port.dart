import 'dart:typed_data';

import '../transport/buffer_transport.dart';

/// SerialPort
///
/// libserialport doesn't support IOS. So wrap it and hope that someone can make an IOS one.
abstract class SerialPort extends BufferTransport {
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

  @override
  Future<int> write(Uint8List bytes) async {
    const int maxChunkSize = 512; // 最大分片大小
    int totalWritten = 0; // 已写入的总字节数
    int offset = 0; // 当前写入位置

    while (offset < bytes.length) {
      // 计算当前分片大小（不超过剩余字节数和最大分片大小）
      final int chunkSize = (bytes.length - offset) > maxChunkSize
          ? maxChunkSize
          : bytes.length - offset;

      // 获取当前分片的字节数据
      final Uint8List chunk =
          Uint8List.sublistView(bytes, offset, offset + chunkSize);

      // 记录本次分片已写入量
      int chunkWritten = 0;

      // 循环写入直到当前分片完全写入
      while (chunkWritten < chunkSize) {
        // print("chunkWritten $chunkWritten chunkSize $chunkSize");
        // 写入分片并等待完成
        final written = await directWrite(
            Uint8List.sublistView(chunk, chunkWritten, chunkSize));
        // print("written $written");
        if (written < 0) {
          return written;
        }

        // 更新写入位置
        chunkWritten += written;
        offset += written;
        totalWritten += written;
      }
    }

    // print("Total bytes written: $totalWritten");
    return totalWritten;
  }
}
