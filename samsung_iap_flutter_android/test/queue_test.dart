import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samsung_iap_flutter_android/samsung_iap_flutter_android.dart';
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
