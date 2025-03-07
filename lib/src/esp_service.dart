import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_nesigner_sdk/src/esp_callback.dart';
import 'package:flutter_nesigner_sdk/src/serial_port/serial_port.dart';
import 'package:flutter_nesigner_sdk/src/transport/transport.dart';
import 'package:libserialport/libserialport.dart' as ls;
import 'package:encrypt/encrypt.dart' as encrypt;

import '../flutter_nesigner_sdk.dart';
import 'utils/crc_util.dart';

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

  static const String EMPTY_PUBKEY =
      "0000000000000000000000000000000000000000000000000000000000000000";

  bool _isReading = false;

  Transport transport;

  Uint8List _receiveBuffer = Uint8List(0); // 接收缓冲区

  EspService(this.transport);

  static List<String> get availablePorts {
    if (Platform.isIOS) {
      return [];
    }

    return ls.SerialPort.availablePorts;
  }

  Map<String, EspCallback> _callbacks = {};

  void onMsg(ReceivedMessage reMsg) {
    var msgId = bytesToHex(reMsg.id);
    var callback = _callbacks[msgId];
    if (callback != null) {
      callback(reMsg);
    }

    _callbacks.remove(msgId);
  }

  Future<int?> ping() async {
    var msgIdByte = randomMessageId();

    var startTime = DateTime.now().millisecondsSinceEpoch;
    var completer = Completer<int?>();

    sendMessage(
        callback: (reMsg) {
          var endTime = DateTime.now().millisecondsSinceEpoch;
          completer.complete(endTime - startTime);
        },
        messageType: MsgType.PING,
        messageId: msgIdByte,
        pubkey: EMPTY_PUBKEY,
        data: Uint8List.fromList([]));

    return await completer.future.timeout(const Duration(seconds: 10));
  }

  Future<String?> echo(String aesKey, String msgContent) {
    var msgIdByte = randomMessageId();
    var completer = Completer<String?>();

    var data = utf8.encode(msgContent);

    sendMessage(
        callback: (reMsg) {
          var decryptedData = aesDecrypt(aesKey, reMsg.encryptedData, reMsg.iv);
          completer.complete(utf8.decode(decryptedData));
        },
        aesKey: aesKey,
        messageType: MsgType.REMOVE_KEY,
        messageId: msgIdByte,
        pubkey: EMPTY_PUBKEY,
        data: data);

    return completer.future;
  }

  Future<int?> updateKey(String aesKey, String key) async {
    var msgIdByte = randomMessageId();
    var completer = Completer<int?>();

    final data = Uint8List.fromList([
      ...hexToBytes(key),
      ...hexToBytes(aesKey),
    ]);

    sendMessage(
        callback: (reMsg) {
          completer.complete(reMsg.result);
        },
        aesKey: aesKey,
        messageType: MsgType.UPDATE_KEY,
        messageId: msgIdByte,
        pubkey: EMPTY_PUBKEY,
        data: data);

    return await completer.future;
  }

  Future<int?> removeKey(String aesKey) async {
    var msgIdByte = randomMessageId();
    var completer = Completer<int?>();

    var iv = randomMessageId();
    var data = Uint8List.fromList(iv);

    sendMessage(
        callback: (reMsg) {
          completer.complete(reMsg.result);
        },
        aesKey: aesKey,
        messageType: MsgType.REMOVE_KEY,
        messageId: msgIdByte,
        pubkey: EMPTY_PUBKEY,
        data: data);

    return completer.future;
  }

  Timer? _timer;

  void start() {
    _openAndCheck();
  }

  void stop() {
    if (_timer != null) {
      _timer!.cancel();
    }

    if (transport.isOpen) {
      transport.close();
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
    if (!transport.isOpen) {
      transport.open();
    }
  }

  Uint8List randomMessageId() {
    var messageId = Uint8List(16);
    var random = Random();
    for (var i = 0; i < 16; i++) {
      messageId[i] = random.nextInt(256);
    }

    return messageId;
  }

  // 发送消息
  void sendMessage({
    EspCallback? callback,
    String? aesKey,
    required int messageType,
    required Uint8List messageId,
    required String pubkey,
    required Uint8List data,
    Uint8List? iv,
  }) {
    if (callback != null) {
      _callbacks[bytesToHex(messageId)] = callback;
    }

    iv ??= randomMessageId();

    if (aesKey != null) {
      data = aesEncrypt(aesKey, data, iv);
    }
    int dataLength = data.length;
    final header = _buildHeader(dataLength);
    final crc = CRCUtil.crc16Calculate(data);

    print("send head ${data.length}");

    final output = Uint8List.fromList([
      ...intToTwoBytes(messageType),
      ...messageId,
      ...hexToBytes(pubkey),
      ...iv,
      ...intToTwoBytes(crc),
      ...header,
      ...data,
    ]);

    print("send fullLength ${output.length}");
    print(output);

    transport.write(output);
  }

  // 开始监听消息
  void startListening() {
    _isReading = true;
    transport.listen((data) {
      print(data);
      // 将新数据追加到缓冲区
      _receiveBuffer = Uint8List.fromList([..._receiveBuffer, ...data]);
      _processBuffer();
    });
  }

  // 2+16+2+32+16+2+4=74
  static int PREFIX_LENGTH = 74;

  // 缓冲区分帧处理方法
  void _processBuffer() {
    while (true) {
      // 检查最小包头长度
      if (_receiveBuffer.length < PREFIX_LENGTH) return;

      // 解析长度头（最后4字节的包头）
      final headerBytes =
          _receiveBuffer.sublist(PREFIX_LENGTH - 4, PREFIX_LENGTH);
      final totalLen =
          ByteData.sublistView(headerBytes).getUint32(0, Endian.big);

      print("receive head $totalLen");
      print("receive fullLength ${_receiveBuffer.length}");
      print("type ${twoBytesToInt(_receiveBuffer.sublist(0, 2))}");
      print("id ${bytesToHex(_receiveBuffer.sublist(2, 18))}");

      // 计算完整帧长度
      final fullFrameLength = PREFIX_LENGTH + totalLen;

      // 检查是否收到完整帧
      if (_receiveBuffer.length < fullFrameLength) return;

      // 提取完整帧数据
      final frameData = _receiveBuffer.sublist(0, fullFrameLength);
      _receiveBuffer = _receiveBuffer.sublist(fullFrameLength);

      // 处理单个数据帧
      _parseSingleFrame(frameData);
    }
  }

  // 单帧解析方法
  void _parseSingleFrame(Uint8List data) {
    try {
      final message = ReceivedMessage(
        type: twoBytesToInt(data.sublist(0, 2)),
        id: data.sublist(2, 18),
        result: twoBytesToInt(data.sublist(18, 20)),
        pubkey: bytesToHex(data.sublist(20, 52)),
        iv: data.sublist(52, 68),
        receivedCrc: twoBytesToInt(data.sublist(68, 70)),
        dataLength:
            ByteData.sublistView(data.sublist(70, 74)).getUint32(0, Endian.big),
        encryptedData: data.sublist(74, data.length),
      );

      if (message.isValid) {
        onMsg(message);
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
    transport.close();
  }

  // AES加密
  Uint8List aesEncrypt(String aesKey, Uint8List input, Uint8List messageId) {
    final key = encrypt.Key.fromUtf8(aesKey);
    final iv = encrypt.IV(messageId);
    final encrypter =
        encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.ctr));
    return encrypter.encryptBytes(input, iv: iv).bytes;
  }

  // AES解密
  Uint8List aesDecrypt(String aesKey, Uint8List input, Uint8List ivData) {
    final key = encrypt.Key.fromUtf8(aesKey);
    final iv = encrypt.IV(ivData);
    final encrypter =
        encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.ctr));
    return Uint8List.fromList(
        encrypter.decryptBytes(encrypt.Encrypted(input), iv: iv));
  }

  // 构建4字节长度头
  Uint8List _buildHeader(int dataLength) {
    final header = ByteData(4);
    header.setUint32(0, dataLength, Endian.big);
    return header.buffer.asUint8List();
  }

  // 将 int 数字保存到 2 位字节里面
  List<int> intToTwoBytes(int number) {
    // 确保数字在 16 位无符号整数的范围内（0 到 65535）
    if (number < 0 || number > 65535) {
      throw ArgumentError('Number must be in the range of 0 to 65535');
    }
    // 高字节
    int highByte = (number >> 8) & 0xFF;
    // 低字节
    int lowByte = number & 0xFF;
    return [highByte, lowByte];
  }

// 将 2 位字节转换成为数字
  int twoBytesToInt(List<int> bytes) {
    if (bytes.length != 2) {
      throw ArgumentError('The list must contain exactly 2 bytes');
    }
    // 高字节左移 8 位，然后与低字节进行按位或运算
    return (bytes[0] << 8) | bytes[1];
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
  final int result;
  final String pubkey;
  final Uint8List iv;
  final int dataLength;
  final Uint8List encryptedData;
  final int receivedCrc;

  ReceivedMessage({
    required this.type,
    required this.id,
    required this.result,
    required this.pubkey,
    required this.iv,
    required this.dataLength,
    required this.encryptedData,
    required this.receivedCrc,
  });

  bool get isValid {
    final calculatedCrc = CRCUtil.crc16Calculate(encryptedData);
    return calculatedCrc == receivedCrc;
  }

  // Uint8List get decryptedData {
  //   final communicator = NostrUartCommunicator(''); // 需要实际的端口名
  //   return communicator._aesDecrypt(encryptedData, id);
  // }
}
