import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:samsung_iap_flutter/samsung_iap_flutter.dart';
import 'package:samsung_iap_flutter_example/main.dart';

/// Product IDs the license tester is known to own, comma-separated.
const ownedIdsDefine = String.fromEnvironment('SAMSUNG_IAP_OWNED_IDS');

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

  test('getOwnedProducts lists what the tester owns', () async {
    final ownedIds = idsFrom(ownedIdsDefine);

    final owned = await iap.getOwnedProducts();

    expect(owned.map((p) => p.productId), containsAll(ownedIds));
    for (final product in owned) {
      expect(product.purchaseId, isNotEmpty, reason: product.productId);
      expect(product.paymentId, isNotEmpty, reason: product.productId);
      expect(
        product.type,
        isNot(SamsungProductType.unknown),
        reason: product.productId,
      );
      expect(
        product.acknowledgedStatus,
        isNot(AcknowledgedStatus.unknown),
        reason: product.productId,
      );
      expect(product.purchaseDate, isNotNull, reason: product.productId);
      expect(product.rawJson, contains(product.purchaseId));
      if (product.type == SamsungProductType.subscription) {
        expect(
          product.subscriptionEndDate,
          isNotNull,
          reason: product.productId,
        );
      }
    }

    final items = await iap.getOwnedProducts(filter: OwnedProductFilter.item);
    expect(items.map((p) => p.type), everyElement(SamsungProductType.item));
  });
}
