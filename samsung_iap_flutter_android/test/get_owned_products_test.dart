import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samsung_iap_flutter_android/samsung_iap_flutter_android.dart';
import 'package:samsung_iap_flutter_android/src/messages.g.dart';
import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

import 'helpers.dart';

PlatformSubscriptionPriceChange priceChangeWire({
  String startDate = '2026-06-01 00:00:00',
  double originalLocalPrice = 7.99,
  double newLocalPrice = 8.99,
  bool? isConsented = true,
  String priceChangeMode = 'PRICE_INCREASE_USER_AGREEMENT_REQUIRED',
}) => PlatformSubscriptionPriceChange(
  subscriptionDurationUnit: 'MONTH',
  subscriptionDurationMultiplier: '1',
  startDate: startDate,
  originalLocalPrice: originalLocalPrice,
  originalLocalPriceString: '£7.99',
  newLocalPrice: newLocalPrice,
  newLocalPriceString: '£8.99',
  isConsented: isConsented,
  priceChangeMode: priceChangeMode,
);

PlatformOwnedProduct ownedWire({
  String itemId = 'monthly',
  double? itemPrice = 7.99,
  String type = 'subscription',
  String purchaseDate = '2026-01-01 09:00:00',
  String subscriptionEndDate = '2026-02-01 09:00:00',
  PlatformSubscriptionPriceChange? subscriptionPriceChange,
  String acknowledgedStatus = 'ACKNOWLEDGED',
  String obfuscatedAccountId = 'account',
  String obfuscatedProfileId = 'profile',
}) => PlatformOwnedProduct(
  itemId: itemId,
  itemName: 'Monthly',
  itemPrice: itemPrice,
  itemPriceString: '£7.99',
  currencyCode: 'GBP',
  type: type,
  paymentId: 'TPMTID20260101',
  purchaseId: 'a1b2c3',
  purchaseDate: purchaseDate,
  subscriptionEndDate: subscriptionEndDate,
  subscriptionPriceChange: subscriptionPriceChange,
  acknowledgedStatus: acknowledgedStatus,
  obfuscatedAccountId: obfuscatedAccountId,
  obfuscatedProfileId: obfuscatedProfileId,
  json: '{"mItemId":"$itemId"}',
);

void main() {
  late MockHostApi api;
  late SamsungIapFlutterAndroid plugin;

  setUp(() async {
    (api, plugin) = newPlugin();
    await initializeForTest(plugin);
  });

  void answerOwned(List<PlatformOwnedProduct> owned) =>
      when(() => api.getOwnedList(any())).thenAnswer((_) async => owned);

  test('sends every filter', () async {
    answerOwned([]);
    final filters = {
      OwnedProductFilter.item: PlatformOwnedProductFilter.item,
      OwnedProductFilter.subscription: PlatformOwnedProductFilter.subscription,
      OwnedProductFilter.all: PlatformOwnedProductFilter.all,
    };
    for (final MapEntry(key: filter, value: wire) in filters.entries) {
      await plugin.getOwnedProducts(filter);

      verify(() => api.getOwnedList(wire)).called(1);
    }
  });

  test('maps a subscription with a pending price change', () async {
    answerOwned([ownedWire(subscriptionPriceChange: priceChangeWire())]);

    expect(await plugin.getOwnedProducts(OwnedProductFilter.all), [
      OwnedProduct(
        productId: 'monthly',
        name: 'Monthly',
        purchaseId: 'a1b2c3',
        paymentId: 'TPMTID20260101',
        type: SamsungProductType.subscription,
        purchaseDate: DateTime(2026, 1, 1, 9),
        subscriptionEndDate: DateTime(2026, 2, 1, 9),
        acknowledgedStatus: AcknowledgedStatus.acknowledged,
        priceChange: SubscriptionPriceChange(
          mode: PriceChangeMode.increaseConsentRequired,
          consented: true,
          startDate: DateTime(2026, 6),
          originalPrice: 7.99,
          originalFormattedPrice: '£7.99',
          newPrice: 8.99,
          newFormattedPrice: '£8.99',
          period: const SubscriptionPeriod(count: 1, unit: PeriodUnit.month),
        ),
        obfuscatedAccountId: 'account',
        obfuscatedProfileId: 'profile',
        price: 7.99,
        formattedPrice: '£7.99',
        currencyCode: 'GBP',
        rawJson: '{"mItemId":"monthly"}',
      ),
    ]);
  });

  test('maps an item whose optional fields Samsung left empty', () async {
    answerOwned([
      ownedWire(
        itemPrice: double.nan,
        type: 'item',
        purchaseDate: '',
        subscriptionEndDate: '',
        acknowledgedStatus: 'PENDING',
        obfuscatedAccountId: '',
        obfuscatedProfileId: '',
      ),
    ]);

    final owned = (await plugin.getOwnedProducts(.item)).single;

    expect(owned.type, SamsungProductType.item);
    expect(owned.price, isNull);
    expect(owned.purchaseDate, isNull);
    expect(owned.subscriptionEndDate, isNull);
    expect(owned.acknowledgedStatus, AcknowledgedStatus.unknown);
    expect(owned.priceChange, isNull);
    expect(owned.obfuscatedAccountId, isNull);
    expect(owned.obfuscatedProfileId, isNull);
  });

  test('maps the consent flag, reading a missing one as no', () async {
    final flags = <bool?, bool>{true: true, false: false, null: false};
    for (final MapEntry(key: wire, value: consented) in flags.entries) {
      answerOwned([
        ownedWire(subscriptionPriceChange: priceChangeWire(isConsented: wire)),
      ]);

      final owned = (await plugin.getOwnedProducts(.subscription)).single;

      expect(owned.priceChange?.consented, consented, reason: '$wire');
    }
  });

  test('maps a price change Samsung could not fully parse', () async {
    answerOwned([
      ownedWire(
        subscriptionPriceChange: priceChangeWire(
          startDate: '',
          originalLocalPrice: double.nan,
          newLocalPrice: double.nan,
          priceChangeMode: '',
        ),
      ),
    ]);

    final change = (await plugin.getOwnedProducts(.all)).single.priceChange;

    expect(change?.mode, PriceChangeMode.unknown);
    expect(change?.startDate, isNull);
    expect(change?.originalPrice, isNull);
    expect(change?.newPrice, isNull);
  });
}
