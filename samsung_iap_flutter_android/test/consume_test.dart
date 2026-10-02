import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samsung_iap_flutter_android/samsung_iap_flutter_android.dart';
import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

import 'helpers.dart';

void main() {
  late MockHostApi api;
  late SamsungIapFlutterAndroid plugin;

  setUp(() async {
    (api, plugin) = newPlugin();
    await initializeForTest(plugin);
  });

  test('sends the purchase IDs comma-joined', () async {
    when(() => api.consumePurchasedItems(any())).thenAnswer((_) async => []);

    await plugin.consume(['a1b2c3']);
    await plugin.consume(['a1b2c3', 'd4e5f6']);

    verify(() => api.consumePurchasedItems('a1b2c3')).called(1);
    verify(() => api.consumePurchasedItems('a1b2c3,d4e5f6')).called(1);
  });

  test('returns a result per purchase, failed ones included', () async {
    when(() => api.consumePurchasedItems(any()))
        .thenAnswer((_) async => ackWires);

    expect(await plugin.consume(['a1b2c3', 'bogus', 'd4e5f6']), ackResults);
  });

  test('throws when the call as a whole fails', () async {
    when(() => api.consumePurchasedItems(any())).thenThrow(sdkError(-1008));

    await expectLater(
      plugin.consume(['a1b2c3']),
      throwsA(
        isA<SamsungIapException>()
            .having((e) => e.kind, 'kind', SamsungIapErrorKind.network)
            .having((e) => e.code, 'code', -1008),
      ),
    );
  });

  test('maps the bridge errors of the call', () async {
    final kinds = {
      'not_sent': SamsungIapErrorKind.busy,
      'store_unavailable': SamsungIapErrorKind.storeUnavailable,
      'not_initialized': SamsungIapErrorKind.notInitialized,
      'timeout': SamsungIapErrorKind.network,
    };
    for (final MapEntry(key: code, value: kind) in kinds.entries) {
      when(() => api.consumePurchasedItems(any()))
          .thenThrow(PlatformException(code: code));

      await expectLater(
        plugin.consume(['a1b2c3']),
        throwsKind(kind),
        reason: code,
      );
    }
  });
}
