import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_nesigner_sdk_method_channel.dart';

abstract class FlutterNesignerSdkPlatform extends PlatformInterface {
  /// Constructs a FlutterNesignerSdkPlatform.
  FlutterNesignerSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterNesignerSdkPlatform _instance =
      MethodChannelFlutterNesignerSdk();

  /// The default instance of [FlutterNesignerSdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterNesignerSdk].
  static FlutterNesignerSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterNesignerSdkPlatform] when
  /// they register themselves.
  static set instance(FlutterNesignerSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
