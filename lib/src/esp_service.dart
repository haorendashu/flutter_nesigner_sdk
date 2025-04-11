import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_nesigner_sdk/src/consts/msg_result.dart';
import 'package:flutter_nesigner_sdk/src/esp_callback.dart';
import 'package:flutter_nesigner_sdk/src/nostr_util/keys.dart';
import 'package:flutter_nesigner_sdk/src/nostr_util/nip44_v2.dart';
// import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/export.dart';

import '../flutter_nesigner_sdk.dart';
import 'utils/crc_util.dart';
import 'utils/hex_util.dart';

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

  static const TIMEOUT = Duration(seconds: 10);

  Transport transport;

  EspService(this.transport);

  Map<String, EspCallback> _callbacks = {};

  void onMsg(ReceivedMessage reMsg) {
    var msgId = HexUtil.bytesToHex(reMsg.id);
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

    return await completer.future.timeout(TIMEOUT);
  }

  Future<String?> echo(Uint8List aesKey, String msgContent) {
    var msgIdByte = randomMessageId();
    var completer = Completer<String?>();

    var data = utf8.encode(msgContent);

    sendMessage(
        callback: (reMsg) {
          if (reMsg.result == MsgResult.OK) {
            var decryptedData =
                aesDecrypt(aesKey, reMsg.encryptedData, reMsg.iv);
            completer.complete(utf8.decode(decryptedData));
          } else {
            completer.complete(null);
          }
        },
        aesKey: aesKey,
        messageType: MsgType.ECHO,
        messageId: msgIdByte,
        pubkey: EMPTY_PUBKEY,
        data: data);

    return completer.future.timeout(EspService.TIMEOUT);
  }

  Future<int?> updateKey(Uint8List aesKey, String key) async {
    var msgIdByte = randomMessageId();
    var completer = Completer<int?>();

    final sourceData = key + HexUtil.bytesToHex(aesKey);
    // print(sourceData);

    var signerTempPubkey = await getTempPubkey();
    if (signerTempPubkey == null) {
      return null;
    }

    var currentPubkey = getPublicKey(key);

    var conversationKey = NIP44V2.shareSecret(key, signerTempPubkey);
    var encryptedText = await NIP44V2.encrypt(sourceData, conversationKey);
    // print("encryptedText $encryptedText");
    // print(Uint8List.fromList(encryptedText.codeUnits));
    // print(utf8.encode(encryptedText));

    sendMessage(
        callback: (reMsg) {
          completer.complete(reMsg.result);
        },
        aesKey: null,
        messageType: MsgType.UPDATE_KEY,
        messageId: msgIdByte,
        pubkey: currentPubkey,
        data: utf8.encode(encryptedText));

    return await completer.future.timeout(EspService.TIMEOUT);
  }

  Future<int?> removeKey(Uint8List aesKey) async {
    var msgIdByte = randomMessageId();
    var completer = Completer<int?>();

    var iv = randomMessageId();
    var data = Uint8List.fromList(iv);

    sendMessage(
        callback: (reMsg) {
          if (reMsg.result == MsgResult.OK) {
            completer.complete(reMsg.result);
          } else {
            completer.complete(null);
          }
        },
        aesKey: aesKey,
        messageType: MsgType.REMOVE_KEY,
        messageId: msgIdByte,
        pubkey: EMPTY_PUBKEY,
        iv: iv,
        data: data);

    return completer.future.timeout(EspService.TIMEOUT);
  }

  Future<String?> getTempPubkey() async {
    var msgIdByte = EspService.randomMessageId();
    var completer = Completer<String?>();

    sendMessage(
        callback: (reMsg) {
          if (reMsg.result == MsgResult.OK) {
            var tempPubkey = HexUtil.bytesToHex(reMsg.encryptedData);
            // print("tempPubkey $tempPubkey");
            completer.complete(tempPubkey);
          } else {
            completer.complete(null);
          }
        },
        messageType: MsgType.GET_TEMP_PUBKEY,
        messageId: msgIdByte,
        pubkey: EspService.EMPTY_PUBKEY,
        data: Uint8List.fromList([]));

    return completer.future.timeout(EspService.TIMEOUT);
  }

  Timer? _timer;

  Future<void> start() async {
    await _openAndCheck();
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
    await _doOpen();

    _timer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        await _doOpen();
      } catch (e) {
        print(e);
      }
    });
  }

  Future<void> _doOpen() async {
    if (!transport.isOpen) {
      await transport.open();
    }
  }

  static Uint8List randomMessageId() {
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
    Uint8List? aesKey,
    required int messageType,
    required Uint8List messageId,
    required String pubkey,
    required Uint8List data,
    Uint8List? iv,
  }) {
    if (callback != null) {
      _callbacks[HexUtil.bytesToHex(messageId)] = callback;
    }

    iv ??= randomMessageId();

    if (aesKey != null) {
      data = aesEncrypt(aesKey, data, iv);
      // print("data encrypted length ${data.length}");
      // print(data);
    }
    int dataLength = data.length;
    final header = _buildHeader(dataLength);
    final crc = CRCUtil.crc16Calculate(data);

    // print("send head ${data.length}");

    final output = Uint8List.fromList([
      ...intToTwoBytes(messageType),
      ...messageId,
      ...HexUtil.hexToBytes(pubkey),
      ...iv,
      ...intToTwoBytes(crc),
      ...header,
      ...data,
    ]);

    // print("send fullLength ${output.length}");
    // print(output);

    transport.write(output);
  }

  // 开始监听消息
  void startListening() {
    transport.listen((data) {
      _parseSingleFrame(data);
    });
  }

  // 单帧解析方法
  void _parseSingleFrame(Uint8List data) {
    try {
      if (data.length < Transport.PREFIX_LENGTH) {
        return;
      }

      final message = ReceivedMessage(
        type: twoBytesToInt(data.sublist(0, 2)),
        id: data.sublist(2, 18),
        result: twoBytesToInt(data.sublist(18, 20)),
        pubkey: HexUtil.bytesToHex(data.sublist(20, 52)),
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

  // AES加密
  Uint8List aesEncrypt(Uint8List aesKey, Uint8List input, Uint8List ivData) {
    final cipherCbc =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()));
    final paramsCbc = PaddedBlockCipherParameters(
        ParametersWithIV(KeyParameter(Uint8List.fromList(aesKey)), ivData),
        null);
    cipherCbc.init(true, paramsCbc);

    return cipherCbc.process(input);
  }

  // AES解密
  Uint8List aesDecrypt(Uint8List aesKey, Uint8List input, Uint8List ivData) {
    final cipherCbc =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()));
    final paramsCbc = PaddedBlockCipherParameters(
        ParametersWithIV(KeyParameter(Uint8List.fromList(aesKey)), ivData),
        null);
    cipherCbc.init(false, paramsCbc);

    return cipherCbc.process(input);
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
    if (dataLength > 0) {
      final calculatedCrc = CRCUtil.crc16Calculate(encryptedData);
      return calculatedCrc == receivedCrc;
    }
    return true;
  }

  // Uint8List get decryptedData {
  //   final communicator = NostrUartCommunicator(''); // 需要实际的端口名
  //   return communicator._aesDecrypt(encryptedData, id);
  // }
}
