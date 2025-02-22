import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crc/crc.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:flutter_nesigner_sdk/src/serial_port/serial_port.dart';
import 'package:libserialport/libserialport.dart' as ls;
import 'package:encrypt/encrypt.dart' as encrypt;

/// EspService .
///
/// Hold a serial_port. Read and write data from serial port.
/// Add some methods for signer.
class EspService {
  static const int baudRate = 115200;
  static const int typeSize = 2;
  static const int idSize = 16;
  static const int pubkeySize = 32;
  static const int headerSize = 4;
  static const int crcSize = 2;
  static const String aesKey = "0123456789ABCDEF";

  bool _isReading = false;

  ls.SerialPort serialPort;

  Uint8List _receiveBuffer = Uint8List(0); // 接收缓冲区

  EspService(this.serialPort);

  static List<String> get availablePorts {
    if (Platform.isIOS) {
      return [];
    }

    return ls.SerialPort.availablePorts;
  }

  Timer? _timer;

  void start() {
    _openAndCheck();

    startListening((msg) {});
  }

  void stop() {
    if (_timer != null) {
      _timer!.cancel();
    }

    if (serialPort.isOpen) {
      serialPort.close();
    }
  }

  Future<void> _openAndCheck() async {
    _doOpen();

    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      try {
        _doOpen();
      } catch (e) {
        print(e);
      }
    });
  }

  void _doOpen() {
    if (!serialPort.isOpen) {
      serialPort.open(mode: ls.SerialPortMode.readWrite);
    }
  }

  // 发送消息
  void sendMessage({
    required int messageType,
    required Uint8List messageId,
    required String pubkey,
    required Uint8List data,
  }) {
    final encrypted = _aesEncrypt(data, messageId);
    final header = _buildHeader(encrypted.length);
    final crc = _calculateCrc(encrypted);

    final output = Uint8List.fromList([
      ..._intTo2Bytes(messageType),
      ...messageId,
      ...hexToBytes(pubkey),
      ...header,
      ...encrypted,
      ..._intTo2Bytes(crc),
    ]);

    serialPort.write(output);
  }

  // 开始监听消息
  void startListening(Function(ReceivedMessage) callback) {
    _isReading = true;
    SerialPortReader reader = SerialPortReader(serialPort);
    reader.stream.listen((data) {
      // 将新数据追加到缓冲区
      _receiveBuffer = Uint8List.fromList([..._receiveBuffer, ...data]);
      _processBuffer(callback);
    });
  }

  // 缓冲区分帧处理方法
  void _processBuffer(Function(ReceivedMessage) callback) {
    while (true) {
      // 检查最小包头长度
      if (_receiveBuffer.length < 54) return; // 2+16+32+4=54

      // 解析长度头（最后4字节的包头）
      final headerBytes = _receiveBuffer.sublist(50, 54);
      final totalLen =
          ByteData.sublistView(headerBytes).getUint32(0, Endian.big);

      // 计算完整帧长度
      final fullFrameLength = 54 + totalLen;

      // 检查是否收到完整帧
      if (_receiveBuffer.length < fullFrameLength) return;

      // 提取完整帧数据
      final frameData = _receiveBuffer.sublist(0, fullFrameLength);
      _receiveBuffer = _receiveBuffer.sublist(fullFrameLength);

      // 处理单个数据帧
      _parseSingleFrame(frameData, callback);
    }
  }

  // 单帧解析方法
  void _parseSingleFrame(Uint8List data, Function(ReceivedMessage) callback) {
    try {
      final message = ReceivedMessage(
        type: _bytesToInt(data.sublist(0, 2)),
        id: data.sublist(2, 18),
        pubkey: bytesToHex(data.sublist(18, 50)),
        dataLength:
            ByteData.sublistView(data.sublist(50, 54)).getUint32(0, Endian.big),
        encryptedData: data.sublist(54, data.length - 2),
        receivedCrc: _bytesToInt(data.sublist(data.length - 2)),
      );

      if (message.isValid) {
        callback(message);
      } else {
        print('CRC校验失败，丢弃消息');
      }
    } catch (e) {
      print('解析消息错误: $e');
    }
  }

  // 停止监听
  void stopListening() {
    _isReading = false;
    serialPort.close();
  }

  // AES加密
  Uint8List _aesEncrypt(Uint8List input, Uint8List messageId) {
    final key = encrypt.Key.fromUtf8(aesKey);
    final iv = encrypt.IV(messageId);
    final encrypter =
        encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.ctr));
    return encrypter.encryptBytes(input, iv: iv).bytes;
  }

  // AES解密
  Uint8List _aesDecrypt(Uint8List input, Uint8List messageId) {
    final key = encrypt.Key.fromUtf8(aesKey);
    final iv = encrypt.IV(messageId);
    final encrypter =
        encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.ctr));
    return Uint8List.fromList(
        encrypter.decryptBytes(encrypt.Encrypted(input), iv: iv));
  }

  // 构建4字节长度头
  Uint8List _buildHeader(int dataLength) {
    final header = ByteData(4);
    header.setUint32(0, dataLength + crcSize, Endian.big);
    return header.buffer.asUint8List();
  }

  // CRC16计算
  int _calculateCrc(Uint8List data) {
    return ccitt.calculate(data);
  }

  // 工具方法：将2字节转换为int
  int _bytesToInt(Uint8List bytes) {
    return ByteData.sublistView(bytes).getUint16(0, Endian.big);
  }

  // 工具方法：将int转换为2字节
  Uint8List _intTo2Bytes(int value) {
    final data = ByteData(2);
    data.setUint16(0, value, Endian.big);
    return data.buffer.asUint8List();
  }

  // 将十六进制字符串转换为字节数据
  Uint8List hexToBytes(String hex) {
    if (hex.length % 2 != 0) {
      throw ArgumentError('Hex string must have an even number of characters');
    }

    final Uint8List bytes = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < hex.length; i += 2) {
      bytes[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return bytes;
  }

// 将字节数据转换为十六进制字符串
  String bytesToHex(Uint8List bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}

class ReceivedMessage {
  final int type;
  final Uint8List id;
  final String pubkey;
  final int dataLength;
  final Uint8List encryptedData;
  final int receivedCrc;

  ReceivedMessage({
    required this.type,
    required this.id,
    required this.pubkey,
    required this.dataLength,
    required this.encryptedData,
    required this.receivedCrc,
  });

  bool get isValid {
    final calculatedCrc = ccitt.calculate(encryptedData);
    return calculatedCrc == receivedCrc;
  }

  // Uint8List get decryptedData {
  //   final communicator = NostrUartCommunicator(''); // 需要实际的端口名
  //   return communicator._aesDecrypt(encryptedData, id);
  // }
}
