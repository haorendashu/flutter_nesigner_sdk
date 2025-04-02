library flutter_nesigner_sdk;

import 'flutter_nesigner_sdk_platform_interface.dart';

export 'src/consts/msg_type.dart';
export 'src/serial_port/base_serial_port.dart';
export 'src/serial_port/enums.dart';
export 'src/serial_port/serial_port.dart';
export 'src/transport/buffer_transport.dart';
export 'src/transport/transport.dart';
export 'src/usb/usb_isolate_transport_worker.dart';
export 'src/usb/usb_isolate_transport.dart';
export 'src/usb/usb_transport.dart';
export 'src/utils/crc_util.dart';
export 'src/utils/crypto_util.dart';
export 'src/esp_service.dart';
export 'src/esp_signer.dart';

class FlutterNesignerSdk {
  Future<String?> getPlatformVersion() {
    return FlutterNesignerSdkPlatform.instance.getPlatformVersion();
  }
}
