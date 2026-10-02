import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samsung_iap_flutter_android/samsung_iap_flutter_android.dart';
import 'package:samsung_iap_flutter_android/src/messages.g.dart';
import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHostApi api;
  late SamsungIapFlutterAndroid plugin;

  setUp(() => (api, plugin) = newPlugin());

  test('can be registered', () {
    SamsungIapFlutterAndroid.registerWith();

    expect(SamsungIapFlutterPlatform.instance, isA<SamsungIapFlutterAndroid>());
  });

  test('initialize sends every operation mode and the dialog flag', () async {
    final modes = {
      OperationMode.production: PlatformOperationMode.production,
      OperationMode.test: PlatformOperationMode.test,
      OperationMode.testFailure: PlatformOperationMode.testFailure,
    };
    for (final MapEntry(key: mode, value: wire) in modes.entries) {
      await plugin.initialize(mode: mode, showErrorDialog: false);

      verify(() => api.initialize(wire, false)).called(1);
    }
  });
}
