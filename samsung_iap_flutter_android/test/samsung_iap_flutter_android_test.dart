import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samsung_iap_flutter_android/samsung_iap_flutter_android.dart';
import 'package:samsung_iap_flutter_android/src/messages.g.dart';
import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

class _MockSamsungIapFlutterApi extends Mock implements SamsungIapFlutterApi;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(SamsungIapFlutterAndroid, () {
    const kPlatformName = 'Android';
    late SamsungIapFlutterAndroid samsungIapFlutter;
    late SamsungIapFlutterApi api;

    setUp(() {
      api = _MockSamsungIapFlutterApi();
      samsungIapFlutter = SamsungIapFlutterAndroid(api: api);
    });

    test('can be registered', () {
      SamsungIapFlutterAndroid.registerWith();
      expect(
        SamsungIapFlutterPlatform.instance,
        isA<SamsungIapFlutterAndroid>(),
      );
    });

    test('getPlatformName returns correct name', () async {
      when(api.getPlatformName).thenAnswer((_) async => kPlatformName);

      await expectLater(
        samsungIapFlutter.getPlatformName(),
        completion(equals(kPlatformName)),
      );

      verify(api.getPlatformName).called(1);
    });
  });
}
