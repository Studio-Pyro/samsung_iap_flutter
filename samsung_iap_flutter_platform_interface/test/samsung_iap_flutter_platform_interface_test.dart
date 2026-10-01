import 'package:flutter_test/flutter_test.dart';
import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';
import 'package:samsung_iap_flutter_platform_interface/src/method_channel_samsung_iap_flutter.dart';

class SamsungIapFlutterMock
    extends SamsungIapFlutterPlatform {
  static const mockPlatformName = 'Mock';

  @override
  Future<String?> getPlatformName() async => mockPlatformName;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SamsungIapFlutterPlatform defaultInstance;

  setUpAll(() {
    defaultInstance = SamsungIapFlutterPlatform.instance;
  });

  test('default instance is MethodChannelSamsungIapFlutter', () {
    expect(defaultInstance, isA<MethodChannelSamsungIapFlutter>());
  });

  group('SamsungIapFlutterPlatformInterface', () {
    late SamsungIapFlutterPlatform
    samsungIapFlutterPlatform;

    setUp(() {
      samsungIapFlutterPlatform = SamsungIapFlutterMock();
      SamsungIapFlutterPlatform.instance =
          samsungIapFlutterPlatform;
    });

    group('getPlatformName', () {
      test('returns correct name', () async {
        expect(
          await SamsungIapFlutterPlatform.instance.getPlatformName(),
          equals(SamsungIapFlutterMock.mockPlatformName),
        );
      });
    });
  });
}
