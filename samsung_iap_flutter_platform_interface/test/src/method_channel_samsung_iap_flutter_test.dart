import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samsung_iap_flutter_platform_interface/src/method_channel_samsung_iap_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const kPlatformName = 'platformName';

  group('$MethodChannelSamsungIapFlutter', () {
    late MethodChannelSamsungIapFlutter
    methodChannelSamsungIapFlutter;
    final log = <MethodCall>[];

    setUp(() {
      methodChannelSamsungIapFlutter = MethodChannelSamsungIapFlutter();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            methodChannelSamsungIapFlutter.methodChannel,
            (methodCall) async {
              log.add(methodCall);
              switch (methodCall.method) {
                case 'getPlatformName':
                  return kPlatformName;
                default:
                  return null;
              }
            },
          );
    });

    tearDown(log.clear);

    test('getPlatformName', () async {
      final platformName = await methodChannelSamsungIapFlutter
          .getPlatformName();
      expect(
        log,
        <Matcher>[isMethodCall('getPlatformName', arguments: null)],
      );
      expect(platformName, equals(kPlatformName));
    });
  });
}
