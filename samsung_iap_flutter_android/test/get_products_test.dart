import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samsung_iap_flutter_android/samsung_iap_flutter_android.dart';
import 'package:samsung_iap_flutter_android/src/messages.g.dart';
import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

import 'helpers.dart';

PlatformProduct productWire({
  String itemId = 'coins_100',
  double? itemPrice = 0.99,
  String type = 'item',
  String subscriptionDurationUnit = '',
  String subscriptionDurationMultiplier = '',
  String tieredSubscriptionYN = '',
  String tieredPrice = '',
  String tieredPriceString = '',
  String tieredSubscriptionDurationUnit = '',
  String tieredSubscriptionDurationMultiplier = '',
  String tieredSubscriptionCount = '',
  String showStartDate = '',
  String showEndDate = '',
  String itemImageUrl = '',
  String itemDownloadUrl = '',
  String freeTrialPeriod = '',
}) => PlatformProduct(
  itemId: itemId,
  itemName: '100 coins',
  itemPrice: itemPrice,
  itemPriceString: '£0.99',
  currencyUnit: '£',
  currencyCode: 'GBP',
  itemDesc: 'A pile of coins',
  type: type,
  subscriptionDurationUnit: subscriptionDurationUnit,
  subscriptionDurationMultiplier: subscriptionDurationMultiplier,
  tieredSubscriptionYN: tieredSubscriptionYN,
  tieredPrice: tieredPrice,
  tieredPriceString: tieredPriceString,
  tieredSubscriptionDurationUnit: tieredSubscriptionDurationUnit,
  tieredSubscriptionDurationMultiplier: tieredSubscriptionDurationMultiplier,
  tieredSubscriptionCount: tieredSubscriptionCount,
  showStartDate: showStartDate,
  showEndDate: showEndDate,
  itemImageUrl: itemImageUrl,
  itemDownloadUrl: itemDownloadUrl,
  freeTrialPeriod: freeTrialPeriod,
  json: '{"mItemId":"$itemId"}',
);

void main() {
  late MockHostApi api;
  late SamsungIapFlutterAndroid plugin;

  setUp(() async {
    (api, plugin) = newPlugin();
    await initializeForTest(plugin);
  });

  test('sends the IDs comma-joined, and none for all products', () async {
    when(() => api.getProductsDetails(any())).thenAnswer((_) async => []);

    await plugin.getProducts(['monthly', 'yearly']);
    await plugin.getProducts([]);

    verify(() => api.getProductsDetails('monthly,yearly')).called(1);
    verify(() => api.getProductsDetails('')).called(1);
  });

  test('maps a subscription with every optional field', () async {
    when(() => api.getProductsDetails(any())).thenAnswer(
      (_) async => [
        productWire(
          itemId: 'monthly',
          itemPrice: 7.99,
          type: 'subscription',
          subscriptionDurationUnit: 'MONTH',
          subscriptionDurationMultiplier: '1',
          tieredSubscriptionYN: 'Y',
          tieredPrice: '0.99',
          tieredPriceString: '£0.99',
          tieredSubscriptionDurationUnit: 'WEEK',
          tieredSubscriptionDurationMultiplier: '2',
          tieredSubscriptionCount: '3',
          showStartDate: '2026-01-01 09:00:00',
          showEndDate: '2027-01-01 09:00:00',
          itemImageUrl: 'https://img.example.com/monthly.png',
          itemDownloadUrl: 'https://dl.example.com/monthly',
          freeTrialPeriod: '7',
        ),
      ],
    );

    expect(await plugin.getProducts(['monthly']), [
      SamsungProduct(
        id: 'monthly',
        name: '100 coins',
        description: 'A pile of coins',
        type: SamsungProductType.subscription,
        price: 7.99,
        formattedPrice: '£0.99',
        currencyCode: 'GBP',
        currencySymbol: '£',
        subscriptionPeriod: const SubscriptionPeriod(
          count: 1,
          unit: PeriodUnit.month,
        ),
        freeTrialDays: 7,
        introductoryOffer: const IntroductoryOffer(
          price: 0.99,
          formattedPrice: '£0.99',
          period: SubscriptionPeriod(count: 2, unit: PeriodUnit.week),
          cycles: 3,
        ),
        availableFrom: DateTime(2026, 1, 1, 9),
        availableUntil: DateTime(2027, 1, 1, 9),
        imageUrl: Uri.parse('https://img.example.com/monthly.png'),
        downloadUrl: Uri.parse('https://dl.example.com/monthly'),
        rawJson: '{"mItemId":"monthly"}',
      ),
    ]);
  });

  test('maps an item whose optional fields Samsung left empty', () async {
    when(() => api.getProductsDetails(any())).thenAnswer(
      (_) async => [productWire(itemPrice: double.nan, type: 'bundle')],
    );

    final product = (await plugin.getProducts([])).single;

    expect(product.type, SamsungProductType.unknown);
    expect(product.price, isNull);
    expect(product.subscriptionPeriod, isNull);
    expect(product.freeTrialDays, isNull);
    expect(product.introductoryOffer, isNull);
    expect(product.availableFrom, isNull);
    expect(product.availableUntil, isNull);
    expect(product.imageUrl, isNull);
    expect(product.downloadUrl, isNull);
  });

  test('drops an introductory offer that is off or incomplete', () async {
    final offers = [
      productWire(
        tieredSubscriptionYN: 'N',
        tieredSubscriptionDurationUnit: 'MONTH',
        tieredSubscriptionDurationMultiplier: '1',
        tieredSubscriptionCount: '3',
      ),
      productWire(
        tieredSubscriptionYN: 'Y',
        tieredSubscriptionDurationUnit: 'MONTH',
        tieredSubscriptionDurationMultiplier: '1',
      ),
      productWire(tieredSubscriptionYN: 'Y', tieredSubscriptionCount: '3'),
    ];
    when(() => api.getProductsDetails(any())).thenAnswer((_) async => offers);

    final products = await plugin.getProducts([]);

    expect(products.map((p) => p.introductoryOffer), [null, null, null]);
  });

  test('keeps an intro offer whose price is not finite', () async {
    when(() => api.getProductsDetails(any())).thenAnswer(
      (_) async => [
        productWire(
          tieredSubscriptionYN: 'Y',
          tieredPrice: 'NaN',
          tieredPriceString: 'Free',
          tieredSubscriptionDurationUnit: 'MONTH',
          tieredSubscriptionDurationMultiplier: '1',
          tieredSubscriptionCount: '1',
        ),
      ],
    );

    final offer = (await plugin.getProducts([])).single.introductoryOffer;

    expect(offer?.price, isNull);
    expect(offer?.formattedPrice, 'Free');
  });
}
