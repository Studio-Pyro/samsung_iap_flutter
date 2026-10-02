import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samsung_iap_flutter_android/samsung_iap_flutter_android.dart';
import 'package:samsung_iap_flutter_android/src/messages.g.dart';
import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

import 'helpers.dart';

/// A call that goes through the serial queue. `stub` answers the host call
/// and reports each send through `sent`.
typedef QueuedCall = ({
  void Function(MockHostApi api, void Function() sent) stub,
  Future<Object?> Function(SamsungIapFlutterAndroid plugin) call,
});

final queuedCalls = <String, QueuedCall>{
  'getProducts': (
    stub: (api, sent) =>
        when(() => api.getProductsDetails(any())).thenAnswer((_) async {
          sent();
          return [];
        }),
    call: (plugin) => plugin.getProducts([]),
  ),
  'getOwnedProducts': (
    stub: (api, sent) =>
        when(() => api.getOwnedList(any())).thenAnswer((_) async {
          sent();
          return [];
        }),
    call: (plugin) => plugin.getOwnedProducts(OwnedProductFilter.all),
  ),
  'purchase': (
    stub: (api, sent) =>
        when(() => api.startPayment(any(), any(), any())).thenAnswer((_) async {
          sent();
          return purchaseWire();
        }),
    call: (plugin) => plugin.purchase('coins_100'),
  ),
  'consume': (
    stub: (api, sent) =>
        when(() => api.consumePurchasedItems(any())).thenAnswer((_) async {
          sent();
          return [];
        }),
    call: (plugin) => plugin.consume(['a1b2c3']),
  ),
  'acknowledge': (
    stub: (api, sent) =>
        when(() => api.acknowledgePurchases(any())).thenAnswer((_) async {
          sent();
          return [];
        }),
    call: (plugin) => plugin.acknowledge(['a1b2c3']),
  ),
};

void main() {
  late MockHostApi api;
  late SamsungIapFlutterAndroid plugin;

  setUp(() => (api, plugin) = newPlugin());

  for (final MapEntry(key: name, value: queued) in queuedCalls.entries) {
    test('$name waits for an earlier call to settle', () async {
      final initialized = Completer<void>();
      when(() => api.initialize(any(), any()))
          .thenAnswer((_) => initialized.future);
      var sends = 0;
      queued.stub(api, () => sends++);

      unawaited(initializeForTest(plugin));
      final result = queued.call(plugin);
      await pumpEventQueue();

      expect(sends, 0, reason: 'sent while initialize was pending');
      initialized.complete();
      await result;
      expect(sends, 1);
    });
  }

  group('a purchase made while owned products load', () {
    late Completer<List<PlatformOwnedProduct>> owned;
    final events = <String>[];

    setUp(() async {
      await initializeForTest(plugin);
      owned = Completer();
      events.clear();
      when(() => api.getOwnedList(any())).thenAnswer((_) {
        events.add('getOwnedList sent');
        return owned.future;
      });
      when(() => api.startPayment(any(), any(), any())).thenAnswer((_) async {
        events.add('startPayment sent');
        return purchaseWire();
      });
    });

    test('is sent once the inquiry answers, and succeeds', () async {
      final loading = plugin.getOwnedProducts(OwnedProductFilter.all);
      final purchase = plugin.purchase('coins_100');
      await pumpEventQueue();

      expect(events, ['getOwnedList sent']);
      owned.complete([]);

      expect(await loading, isEmpty);
      expect((await purchase).purchaseId, 'a1b2c3');
      expect(events, ['getOwnedList sent', 'startPayment sent']);
    });

    test('is sent once a timed-out inquiry settles', () async {
      final loading = plugin.getOwnedProducts(OwnedProductFilter.all);
      final purchase = plugin.purchase('coins_100');
      owned.completeError(PlatformException(code: 'timeout'));

      await expectLater(loading, throwsKind(.network));
      expect((await purchase).purchaseId, 'a1b2c3');
      expect(events, ['getOwnedList sent', 'startPayment sent']);
    });
  });

  test('a failed call does not block the next one', () async {
    when(() => api.getProductsDetails('first'))
        .thenThrow(PlatformException(code: 'not_sent'));
    when(() => api.getProductsDetails('second')).thenAnswer((_) async => []);

    final failed = plugin.getProducts(['first']);
    final next = plugin.getProducts(['second']);

    await expectLater(failed, throwsKind(.busy));
    expect(await next, isEmpty);
  });
}
