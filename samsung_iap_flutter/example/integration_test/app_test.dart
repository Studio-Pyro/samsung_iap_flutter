import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:samsung_iap_flutter/samsung_iap_flutter.dart';
import 'package:samsung_iap_flutter_example/main.dart' as app;

// Runs on an emulator without Galaxy Store.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const iap = SamsungIap();

  group('without Galaxy Store', () {
    setUpAll(() => iap.initialize(mode: OperationMode.test));

    test('getGalaxyStoreStatus reports notInstalled', () async {
      expect(await iap.getGalaxyStoreStatus(), GalaxyStoreStatus.notInstalled);
    });

    test('getProducts fails fast with storeUnavailable', () async {
      final stopwatch = Stopwatch()..start();

      await expectLater(
        iap.getProducts(),
        throwsA(
          isA<SamsungIapException>().having(
            (e) => e.kind,
            'kind',
            SamsungIapErrorKind.storeUnavailable,
          ),
        ),
      );
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('getOwnedProducts fails fast with storeUnavailable', () async {
      final stopwatch = Stopwatch()..start();

      await expectLater(
        iap.getOwnedProducts(),
        throwsA(
          isA<SamsungIapException>().having(
            (e) => e.kind,
            'kind',
            SamsungIapErrorKind.storeUnavailable,
          ),
        ),
      );
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('purchase fails fast with storeUnavailable', () async {
      final stopwatch = Stopwatch()..start();

      await expectLater(
        iap.purchase('coins_100', obfuscatedAccountId: 'account'),
        throwsA(
          isA<SamsungIapException>().having(
            (e) => e.kind,
            'kind',
            SamsungIapErrorKind.storeUnavailable,
          ),
        ),
      );
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('consume and acknowledge fail fast with storeUnavailable', () async {
      final stopwatch = Stopwatch()..start();

      for (final call in [iap.consume, iap.acknowledge]) {
        await expectLater(
          call(['a1b2c3', 'd4e5f6']),
          throwsA(
            isA<SamsungIapException>().having(
              (e) => e.kind,
              'kind',
              SamsungIapErrorKind.storeUnavailable,
            ),
          ),
        );
      }
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('changeSubscriptionPlan fails fast with storeUnavailable', () async {
      final stopwatch = Stopwatch()..start();

      await expectLater(
        iap.changeSubscriptionPlan(
          fromProductId: 'monthly',
          toProductId: 'monthly_premium',
          prorationMode: ProrationMode.instantProratedDate,
        ),
        throwsA(
          isA<SamsungIapException>().having(
            (e) => e.kind,
            'kind',
            SamsungIapErrorKind.storeUnavailable,
          ),
        ),
      );
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
    });

    testWidgets('the example shows the store status and the error', (
      tester,
    ) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Initialize'));
      await tester.pumpAndSettle();
      expect(find.text('Galaxy Store: notInstalled'), findsOneWidget);

      await tester.tap(find.text('Get products'));
      await tester.pumpAndSettle();
      expect(find.textContaining('storeUnavailable'), findsOneWidget);

      await tester.tap(find.text('Get owned products'));
      await tester.pumpAndSettle();
      expect(find.textContaining('storeUnavailable'), findsOneWidget);
    });
  });
}
