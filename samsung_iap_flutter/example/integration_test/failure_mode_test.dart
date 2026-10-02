import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:samsung_iap_flutter/samsung_iap_flutter.dart';

const _bogusId = 'samsung-iap-flutter-bogus';

// Runs on a Samsung device with Galaxy Store, in TEST_FAILURE mode. See
// "Integration tests" in the repository README.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const iap = SamsungIap();

  setUpAll(
    () =>
        iap.initialize(mode: OperationMode.testFailure, showErrorDialog: false),
  );

  // The calls that show no Samsung UI, each with the detail code Samsung
  // documents, or null where it documents none. `purchase` and
  // `changeSubscriptionPlan` are manual checks, because Samsung's test-mode
  // notice blocks every later call.
  final calls = <String, (Future<Object?> Function(), int?)>{
    'getProducts': (() => iap.getProducts([_bogusId]), 9013),
    'getOwnedProducts': (iap.getOwnedProducts, 9000),
    'consume': (() => iap.consume([_bogusId]), 9005),
    'acknowledge': (() => iap.acknowledge([_bogusId]), null),
    'getPromotionEligibility': (
      () => iap.getPromotionEligibility([_bogusId]),
      null,
    ),
  };

  for (final MapEntry(key: name, value: (call, documented)) in calls.entries) {
    test('$name fails with a detail code', () async {
      try {
        final result = await call();
        fail('$name succeeded in TEST_FAILURE mode: $result');
      } on SamsungIapException catch (e) {
        debugPrint('TEST_FAILURE $name: $e');
        expect(
          e.detailCode,
          isNot(9201),
          reason:
              'setup failure, not a TEST_FAILURE result: Samsung reports 9201 '
              'until the app has IAP activated and products registered in '
              'Seller Portal. $e',
        );
        expect(e.kind, SamsungIapErrorKind.general, reason: '$e');
        expect(e.detailCode, documented ?? isNotNull, reason: '$e');
        expect(e.dialogShown, isFalse, reason: '$e');
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
