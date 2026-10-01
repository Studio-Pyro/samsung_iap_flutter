import 'package:flutter_test/flutter_test.dart';
import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

class SamsungIapFlutterMock extends SamsungIapFlutterPlatform {
  static const mockPlatformName = 'Mock';

  @override
  Future<String?> getPlatformName() async => mockPlatformName;
}

class _ImplementsPlatform implements SamsungIapFlutterPlatform {
  @override
  Future<String?> getPlatformName() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SamsungIapFlutterPlatform defaultInstance;

  setUpAll(() {
    defaultInstance = SamsungIapFlutterPlatform.instance;
  });

  test('default instance throws until an implementation registers', () {
    expect(defaultInstance.getPlatformName, throwsUnimplementedError);
  });

  group('SamsungIapFlutterPlatformInterface', () {
    test('rejects an instance that implements instead of extends', () {
      expect(
        () => SamsungIapFlutterPlatform.instance = _ImplementsPlatform(),
        throwsA(isA<AssertionError>()),
      );
    });

    group('getPlatformName', () {
      test('returns correct name', () async {
        SamsungIapFlutterPlatform.instance = SamsungIapFlutterMock();

        expect(
          await SamsungIapFlutterPlatform.instance.getPlatformName(),
          equals(SamsungIapFlutterMock.mockPlatformName),
        );
      });
    });
  });
}
