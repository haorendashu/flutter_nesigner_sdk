import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_nesigner_sdk/flutter_nesigner_sdk.dart';
import 'package:flutter_nesigner_sdk/src/utils/crypto_util.dart';

import 'esp_callback.dart';

class EspSigner {
  late EspService espService;

  late String _aesKey;

  String? _pubkey;

  EspSigner(String key, this.espService, {String? pubkey}) {
    _aesKey = key;
    _pubkey = pubkey;
  }

  void start() {
    espService.start();

    if (_pubkey == null) {
      // getPubkey first!
      getPublicKey();
    }
  }

  void stop() {
    espService.stop();
  }

  bool get isOpen {
    return espService.transport.isOpen;
  }

  Future<String?> getPublicKey() async {
    if (_pubkey != null) {
      return _pubkey;
    }

    var msgIdByte = espService.randomMessageId();
    var completer = Completer<String>();

    var iv = espService.randomMessageId();
    var data = Uint8List.fromList(iv);

    espService.sendMessage(
        callback: (reMsg) {
          var decryptedData =
              espService.aesDecrypt(_aesKey, reMsg.encryptedData, reMsg.id);
          var pubkey = utf8.decode(decryptedData);
          _pubkey = pubkey;
          completer.complete(_pubkey);
        },
        aesKey: _aesKey,
        messageType: MsgType.NOSTR_GET_PUBLIC_KEY,
        messageId: msgIdByte,
        pubkey: EspService.EMPTY_PUBKEY,
        iv: iv,
        data: data);

    return completer.future;
  }

  Future<Map?> signEvent(Map event) async {
    if (!(await _checkPubkey())) {
      return null;
    }

    var msgIdByte = espService.randomMessageId();
    var completer = Completer<Map?>();

    String? eventId;
    var eventIdIntf = event["id"];
    if (eventIdIntf != null) {
      eventId = eventIdIntf;
    } else {
      eventId = genNostrEventId(event);
    }

    if (eventId == null) {
      return null;
    }

    espService.sendMessage(
        callback: (reMsg) {
          var decryptedData =
              espService.aesDecrypt(_aesKey, reMsg.encryptedData, reMsg.id);
          var result = utf8.decode(decryptedData);
          event["sig"] = result;

          completer.complete(event);
        },
        aesKey: _aesKey,
        messageType: MsgType.NOSTR_SIGN_EVENT,
        messageId: msgIdByte,
        pubkey: _pubkey!,
        data: utf8.encode(eventId));

    return completer.future;
  }

  Future<String?> encrypt(pubkey, plaintext) async {
    return _encryptOrDecrypt(MsgType.NOSTR_NIP04_ENCRYPT, pubkey, plaintext);
  }

  Future<String?> decrypt(pubkey, ciphertext) async {
    return _encryptOrDecrypt(MsgType.NOSTR_NIP04_DECRYPT, pubkey, ciphertext);
  }

  Future<String?> nip44Encrypt(pubkey, plaintext) async {
    return _encryptOrDecrypt(MsgType.NOSTR_NIP44_ENCRYPT, pubkey, plaintext);
  }

  Future<String?> nip44Decrypt(pubkey, ciphertext) async {
    return _encryptOrDecrypt(MsgType.NOSTR_NIP44_DECRYPT, pubkey, ciphertext);
  }

  Future<String?> _encryptOrDecrypt(
      int msgType, String pubkey, targetText) async {
    if (!(await _checkPubkey())) {
      return null;
    }

    var msgIdByte = espService.randomMessageId();
    var completer = Completer<String?>();

    espService.sendMessage(
        callback: (reMsg) {
          var decryptedData =
              espService.aesDecrypt(_aesKey, reMsg.encryptedData, reMsg.id);
          var result = utf8.decode(decryptedData);
          completer.complete(result);
        },
        aesKey: _aesKey,
        messageType: MsgType.NOSTR_NIP04_DECRYPT,
        messageId: msgIdByte,
        pubkey: _pubkey!,
        data: utf8.encode(pubkey + targetText));

    return completer.future;
  }

  Future<bool> _checkPubkey() async {
    if (_pubkey == null) {
      await getPublicKey();
    }

    if (_pubkey == null) {
      return false;
    }

    return true;
  }

  String? genNostrEventId(Map map) {
    if (_pubkey == null) {
      return null;
    }

    List list = [];
    list.add(0);
    list.add(_pubkey!);
    list.add(map["created_at"]);
    list.add(map["kind"]);
    list.add(map["tags"]);
    list.add(map["content"]);

    return calculateSHA256FromText(jsonEncode(list));
  }
}
