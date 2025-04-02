import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_nesigner_sdk_platform_interface.dart';

/// An implementation of [FlutterNesignerSdkPlatform] that uses method channels.
class MethodChannelFlutterNesignerSdk extends FlutterNesignerSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_nesigner_sdk');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
