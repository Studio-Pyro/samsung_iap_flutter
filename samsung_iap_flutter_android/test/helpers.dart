import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samsung_iap_flutter_android/samsung_iap_flutter_android.dart';
import 'package:samsung_iap_flutter_android/src/messages.g.dart';
import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

class MockHostApi extends Mock implements SamsungIapHostApi;

/// A plugin over a fresh [MockHostApi] whose `initialize` succeeds.
(MockHostApi, SamsungIapFlutterAndroid) newPlugin() {
  registerFallbackValue(PlatformOperationMode.production);
  registerFallbackValue(PlatformOwnedProductFilter.all);
  final api = MockHostApi();
  when(() => api.initialize(any(), any())).thenAnswer((_) async {});
  return (api, SamsungIapFlutterAndroid(api: api));
}

Future<void> initializeForTest(SamsungIapFlutterAndroid plugin) =>
    plugin.initialize(mode: OperationMode.test, showErrorDialog: true);

Matcher throwsKind(SamsungIapErrorKind kind) =>
    throwsA(isA<SamsungIapException>().having((e) => e.kind, 'kind', kind));
