import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:samsung_iap_flutter/samsung_iap_flutter.dart';
import 'package:samsung_iap_flutter_example/main.dart';

/// Product IDs the license tester is known to own, comma-separated.
const ownedIdsDefine = String.fromEnvironment('SAMSUNG_IAP_OWNED_IDS');

/// A product the license tester does not own yet, for the interactive
/// purchase test.
const purchaseIdDefine = String.fromEnvironment('SAMSUNG_IAP_PURCHASE_ID');

/// An item the license tester does not own, to buy and consume twice.
const consumeIdDefine = String.fromEnvironment('SAMSUNG_IAP_CONSUME_ID');

/// An item the license tester does not own, to buy and acknowledge.
const acknowledgeIdDefine = String.fromEnvironment(
  'SAMSUNG_IAP_ACKNOWLEDGE_ID',
);

/// A subscription tier the license tester is subscribed to, to upgrade from.
const planFromIdDefine = String.fromEnvironment('SAMSUNG_IAP_PLAN_FROM_ID');

/// A pricier tier of the same subscription, to upgrade to and then try to
/// downgrade from.
const planToIdDefine = String.fromEnvironment('SAMSUNG_IAP_PLAN_TO_ID');

const _bogusPurchaseId = 'samsung-iap-flutter-bogus';

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

  test(
    'purchase buys the product while owned products load',
    () async {
      final loading = iap.getOwnedProducts();

      final purchase = await iap.purchase(purchaseIdDefine);

      await loading;
      expect(purchase.productId, purchaseIdDefine);
      expect(purchase.purchaseId, isNotEmpty);
      expect(purchase.paymentId, isNotEmpty);
      expect(purchase.orderId, isNotEmpty);
      expect(purchase.type, isNot(SamsungProductType.unknown));
      expect(purchase.minorStatus, isNot(MinorStatus.unknown));
      expect(purchase.rawJson, contains(purchase.purchaseId));
      final owned = await iap.getOwnedProducts();
      expect(owned.map((p) => p.purchaseId), contains(purchase.purchaseId));
    },
    skip: purchaseIdDefine.isEmpty
        ? 'Set SAMSUNG_IAP_PURCHASE_ID to buy a product interactively.'
        : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'consume makes an item repurchasable, and a batch reports each item',
    () async {
      final first = await iap.purchase(consumeIdDefine);

      expect(await iap.consume([first.purchaseId]), [
        isA<PurchaseAckResult>()
            .having((r) => r.purchaseId, 'purchaseId', first.purchaseId)
            .having((r) => r.status, 'status', AckStatus.success),
      ]);

      final second = await iap.purchase(consumeIdDefine);
      Future<Map<String, AckStatus>> consume(List<String> ids) async => {
        for (final r in await iap.consume(ids)) r.purchaseId: r.status,
      };

      expect(await consume([second.purchaseId, first.purchaseId]), {
        second.purchaseId: AckStatus.success,
        first.purchaseId: AckStatus.alreadyProcessed,
      });
      expect(await consume([second.purchaseId, _bogusPurchaseId]), {
        second.purchaseId: AckStatus.alreadyProcessed,
        _bogusPurchaseId: AckStatus.invalidPurchaseId,
      });
    },
    skip: consumeIdDefine.isEmpty
        ? 'Set SAMSUNG_IAP_CONSUME_ID to buy and consume interactively.'
        : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'acknowledge marks the owned product acknowledged, once',
    () async {
      Future<AcknowledgedStatus> statusOf(String purchaseId) async {
        final owned = await iap.getOwnedProducts();
        return owned
            .singleWhere((p) => p.purchaseId == purchaseId)
            .acknowledgedStatus;
      }

      final purchase = await iap.purchase(acknowledgeIdDefine);
      expect(
        await statusOf(purchase.purchaseId),
        AcknowledgedStatus.notAcknowledged,
      );

      final results = await iap.acknowledge([purchase.purchaseId]);

      expect(results.single.status, AckStatus.success, reason: '$results');
      expect(
        await statusOf(purchase.purchaseId),
        AcknowledgedStatus.acknowledged,
      );
      final again = (await iap.acknowledge([purchase.purchaseId])).single;
      expect(again.status, AckStatus.alreadyProcessed, reason: '$again');
      expect(again.isProcessed, isTrue);
    },
    skip: acknowledgeIdDefine.isEmpty
        ? 'Set SAMSUNG_IAP_ACKNOWLEDGE_ID to buy and acknowledge interactively.'
        : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );

  group(
    'changeSubscriptionPlan',
    () {
      test('upgrades to the pricier tier at once', () async {
        final purchase = await iap.changeSubscriptionPlan(
          fromProductId: planFromIdDefine,
          toProductId: planToIdDefine,
          prorationMode: ProrationMode.instantProratedDate,
        );

        expect(purchase.productId, planToIdDefine);
        expect(purchase.purchaseId, isNotEmpty);
        expect(purchase.orderId, isNotEmpty);
        expect(purchase.type, SamsungProductType.subscription);
        final owned = await iap.getOwnedProducts(
          filter: OwnedProductFilter.subscription,
        );
        expect(owned.map((p) => p.purchaseId), contains(purchase.purchaseId));
      }, timeout: const Timeout(Duration(minutes: 5)));

      test('refuses an instant downgrade with a detail code', () async {
        // Both Samsung guides call this mode upgrade-only.
        try {
          final purchase = await iap.changeSubscriptionPlan(
            fromProductId: planToIdDefine,
            toProductId: planFromIdDefine,
            prorationMode: ProrationMode.instantProratedCharge,
          );
          fail('Samsung accepted an instant downgrade: $purchase');
        } on SamsungIapException catch (e) {
          // TODO(user): record the kind and detail code Samsung reports here,
          // then assert them.
          debugPrint('instant downgrade: $e');
          expect(e.kind, isNot(SamsungIapErrorKind.userCanceled));
        }
      }, timeout: const Timeout(Duration(minutes: 5)));
    },
    skip: planFromIdDefine.isEmpty || planToIdDefine.isEmpty
        ? 'Set SAMSUNG_IAP_PLAN_FROM_ID and SAMSUNG_IAP_PLAN_TO_ID to change '
              'a subscription plan interactively.'
        : false,
  );
}
