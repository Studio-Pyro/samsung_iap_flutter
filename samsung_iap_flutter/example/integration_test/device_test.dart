import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:samsung_iap_flutter/samsung_iap_flutter.dart';
import 'package:samsung_iap_flutter_example/main.dart';

// Runs on a Samsung device with Galaxy Store, signed in as a license tester.
// See "Integration tests" in the repository README.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const iap = SamsungIap();

  setUpAll(() => iap.initialize(mode: OperationMode.test));

  test('Galaxy Store is available', () async {
    expect(await iap.getGalaxyStoreStatus(), GalaxyStoreStatus.available);
  });

  test('getProducts lists the Seller Portal products', () async {
    final products = await iap.getProducts(productIds);

    expect(products, isNotEmpty);
    if (productIds.isNotEmpty) {
      expect(products.map((p) => p.id), unorderedEquals(productIds));
    }
    for (final product in products) {
      expect(
        product.type,
        isNot(SamsungProductType.unknown),
        reason: product.id,
      );
      expect(product.formattedPrice, isNotEmpty, reason: product.id);
      expect(product.currencyCode, hasLength(3), reason: product.id);
      expect(product.price, isNotNull, reason: product.id);
      expect(product.rawJson, contains(product.id));
      if (product.type == SamsungProductType.subscription) {
        expect(product.subscriptionPeriod, isNotNull, reason: product.id);
      }
    }
  });
}
