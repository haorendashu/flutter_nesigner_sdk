import 'package:flutter_nesigner_sdk/src/esp_service.dart';
import 'package:flutter_nesigner_sdk/src/serial_port/serial_port.dart';

class EspSigner {
  late EspService espService;

  String? _pubkey;

  EspSigner(this.espService);

  void start() {
    espService.start();

    if (_pubkey == null) {
      // getPubkey first!
    }
  }

  void stop() {
    espService.stop();
  }

  bool get isOpen {
    return espService.serialPort.isOpen;
  }

  Future<String?> getPublicKey() async {}

  Future<Map?> signEvent(Map event) async {}

  Future<String?> encrypt(pubkey, plaintext) async {}

  Future<String?> decrypt(pubkey, ciphertext) async {}

  Future<String?> nip44Encrypt(pubkey, plaintext) async {}

  Future<String?> nip44Decrypt(pubkey, ciphertext) async {}
}
