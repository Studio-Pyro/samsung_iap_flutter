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

  setUpAll(() => iap.initialize(mode: OperationMode.testFailure));

  // The detail code Samsung documents for each call, or null where it
  // documents none.
  final calls = <String, (Future<Object?> Function(), int?)>{
    'getProducts': (() => iap.getProducts([_bogusId]), 9013),
    'getOwnedProducts': (iap.getOwnedProducts, 9000),
    'purchase': (() => iap.purchase(_bogusId), 9014),
    'consume': (() => iap.consume([_bogusId]), 9005),
    'acknowledge': (() => iap.acknowledge([_bogusId]), null),
    'changeSubscriptionPlan': (
      () => iap.changeSubscriptionPlan(
        fromProductId: _bogusId,
        toProductId: '$_bogusId-2',
        prorationMode: ProrationMode.deferred,
      ),
      null,
    ),
    'getPromotionEligibility': (
      () => iap.getPromotionEligibility([_bogusId]),
      null,
    ),
  };

  for (final MapEntry(key: name, value: (call, documented)) in calls.entries) {
    test('$name fails with general and a detail code', () async {
      try {
        final result = await call();
        fail('$name succeeded in TEST_FAILURE mode: $result');
      } on SamsungIapException catch (e) {
        // TODO(user): S7 acceptance #2. Record the detail code of each call
        // in the root README, and assert it here where Samsung documents
        // none.
        debugPrint('TEST_FAILURE $name: $e');
        expect(e.kind, SamsungIapErrorKind.general, reason: '$e');
        expect(e.detailCode, documented ?? isNotNull, reason: '$e');
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
