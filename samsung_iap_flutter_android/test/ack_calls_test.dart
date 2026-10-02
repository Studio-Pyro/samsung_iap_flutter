import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samsung_iap_flutter_android/samsung_iap_flutter_android.dart';
import 'package:samsung_iap_flutter_android/src/messages.g.dart';
import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

import 'helpers.dart';

/// `consume` and `acknowledge`, which differ only in the host method and in
/// the bridge errors they can raise.
typedef AckCall = ({
  Future<List<PlatformAckResult>> Function(MockHostApi api, String ids) host,
  Future<List<PurchaseAckResult>> Function(
    SamsungIapFlutterAndroid plugin,
    List<String> ids,
  )
  call,
  Map<String, SamsungIapErrorKind> extraKinds,
});

final ackCalls = <String, AckCall>{
  'consume': (
    host: (api, ids) => api.consumePurchasedItems(ids),
    call: (plugin, ids) => plugin.consume(ids),
    extraKinds: {},
  ),
  'acknowledge': (
    host: (api, ids) => api.acknowledgePurchases(ids),
    call: (plugin, ids) => plugin.acknowledge(ids),
    extraKinds: {
      'store_update_required': SamsungIapErrorKind.storeUpdateRequired,
    },
  ),
};

void main() {
  late MockHostApi api;
  late SamsungIapFlutterAndroid plugin;

  setUp(() async {
    (api, plugin) = newPlugin();
    await initializeForTest(plugin);
  });

  for (final MapEntry(key: name, value: ack) in ackCalls.entries) {
    group(name, () {
      test('sends the purchase IDs comma-joined', () async {
        when(() => ack.host(api, any())).thenAnswer((_) async => []);

        await ack.call(plugin, ['a1b2c3']);
        await ack.call(plugin, ['a1b2c3', 'd4e5f6']);

        verify(() => ack.host(api, 'a1b2c3')).called(1);
        verify(() => ack.host(api, 'a1b2c3,d4e5f6')).called(1);
      });

      test('returns a result per purchase, failed ones included', () async {
        when(() => ack.host(api, any())).thenAnswer((_) async => ackWires);

        expect(
          await ack.call(plugin, ['a1b2c3', 'bogus', 'd4e5f6']),
          ackResults,
        );
      });

      test('throws when the call as a whole fails', () async {
        when(() => ack.host(api, any())).thenThrow(sdkError(-1008));

        await expectLater(
          ack.call(plugin, ['a1b2c3']),
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
          ...ack.extraKinds,
        };
        for (final MapEntry(key: code, value: kind) in kinds.entries) {
          when(() => ack.host(api, any()))
              .thenThrow(PlatformException(code: code));

          await expectLater(
            ack.call(plugin, ['a1b2c3']),
            throwsKind(kind),
            reason: code,
          );
        }
      });
    });
  }
}
