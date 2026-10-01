import 'package:flutter/foundation.dart';
import 'package:samsung_iap_flutter_android/src/messages.g.dart';
import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

/// {@template samsung_iap_flutter_android}
/// The Android implementation of [SamsungIapFlutterPlatform].
/// {@endtemplate}
class SamsungIapFlutterAndroid extends SamsungIapFlutterPlatform {
  /// {@macro samsung_iap_flutter_android}
  new({@visibleForTesting SamsungIapFlutterApi? api})
    : api = api ?? SamsungIapFlutterApi();

  /// The API used to interact with the native platform.
  final SamsungIapFlutterApi api;

  /// Registers this class as the default instance of
  /// [SamsungIapFlutterPlatform].
  static void registerWith() {
    SamsungIapFlutterPlatform.instance = SamsungIapFlutterAndroid();
  }

  @override
  Future<String?> getPlatformName() {
    return api.getPlatformName();
  }
}
