import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:samsung_iap_flutter/samsung_iap_flutter.dart';
import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

class MockSamsungIapFlutterPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements SamsungIapFlutterPlatform;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(SamsungIapFlutterPlatform, () {
    late SamsungIapFlutterPlatform
    samsungIapFlutterPlatform;

    setUp(() {
      samsungIapFlutterPlatform =
          MockSamsungIapFlutterPlatform();
      SamsungIapFlutterPlatform.instance =
          samsungIapFlutterPlatform;
    });

    group('getPlatformName', () {
      test(
        'returns correct name when platform implementation exists',
        () async {
          const platformName = '__test_platform__';
          when(
            () => samsungIapFlutterPlatform.getPlatformName(),
          ).thenAnswer((_) async => platformName);

          final actualPlatformName = await getPlatformName();
          expect(actualPlatformName, equals(platformName));
        },
      );

      test(
        'throws exception when platform implementation is missing',
        () async {
          when(
            () => samsungIapFlutterPlatform.getPlatformName(),
          ).thenAnswer((_) async => null);

          expect(getPlatformName, throwsException);
        },
      );
    });
  });
}
