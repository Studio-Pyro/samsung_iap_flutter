import 'package:flutter_test/flutter_test.dart';
import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

class _ExtendsPlatform extends SamsungIapFlutterPlatform;

class _ImplementsPlatform implements SamsungIapFlutterPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SamsungProduct _product({
  String id = 'coins_100',
  String name = '100 coins',
  String description = '',
  SamsungProductType type = SamsungProductType.item,
  double? price = 0.99,
  String formattedPrice = '£0.99',
  String currencyCode = 'GBP',
  String currencySymbol = '£',
  SubscriptionPeriod? subscriptionPeriod,
  int? freeTrialDays,
  IntroductoryOffer? introductoryOffer,
  DateTime? availableFrom,
  DateTime? availableUntil,
  Uri? imageUrl,
  Uri? downloadUrl,
  String rawJson = '{}',
}) => SamsungProduct(
  id: id,
  name: name,
  description: description,
  type: type,
  price: price,
  formattedPrice: formattedPrice,
  currencyCode: currencyCode,
  currencySymbol: currencySymbol,
  subscriptionPeriod: subscriptionPeriod,
  freeTrialDays: freeTrialDays,
  introductoryOffer: introductoryOffer,
  availableFrom: availableFrom,
  availableUntil: availableUntil,
  imageUrl: imageUrl,
  downloadUrl: downloadUrl,
  rawJson: rawJson,
);

SubscriptionPriceChange _priceChange({
  PriceChangeMode mode = PriceChangeMode.increaseConsentRequired,
  bool consented = false,
  DateTime? startDate,
  double? originalPrice = 7.99,
  String originalFormattedPrice = '£7.99',
  double? newPrice = 8.99,
  String newFormattedPrice = '£8.99',
  SubscriptionPeriod? period,
}) => SubscriptionPriceChange(
  mode: mode,
  consented: consented,
  startDate: startDate,
  originalPrice: originalPrice,
  originalFormattedPrice: originalFormattedPrice,
  newPrice: newPrice,
  newFormattedPrice: newFormattedPrice,
  period: period,
);

OwnedProduct _owned({
  String productId = 'monthly',
  String name = 'Monthly',
  String purchaseId = 'a1b2c3',
  String paymentId = 'TPMTID20260101',
  SamsungProductType type = SamsungProductType.subscription,
  DateTime? purchaseDate,
  DateTime? subscriptionEndDate,
  AcknowledgedStatus acknowledgedStatus = AcknowledgedStatus.acknowledged,
  SubscriptionPriceChange? priceChange,
  String? obfuscatedAccountId,
  String? obfuscatedProfileId,
  double? price = 7.99,
  String formattedPrice = '£7.99',
  String currencyCode = 'GBP',
  String rawJson = '{}',
}) => OwnedProduct(
  productId: productId,
  name: name,
  purchaseId: purchaseId,
  paymentId: paymentId,
  type: type,
  purchaseDate: purchaseDate,
  subscriptionEndDate: subscriptionEndDate,
  acknowledgedStatus: acknowledgedStatus,
  priceChange: priceChange,
  obfuscatedAccountId: obfuscatedAccountId,
  obfuscatedProfileId: obfuscatedProfileId,
  price: price,
  formattedPrice: formattedPrice,
  currencyCode: currencyCode,
  rawJson: rawJson,
);

SamsungPurchase _purchase({
  String productId = 'coins_100',
  String name = '100 coins',
  String purchaseId = 'a1b2c3',
  String paymentId = 'TPMTID20260101',
  String orderId = 'S20260101KRA1234567',
  SamsungProductType type = SamsungProductType.item,
  DateTime? purchaseDate,
  MinorStatus minorStatus = MinorStatus.notMinor,
  String? obfuscatedAccountId,
  String? obfuscatedProfileId,
  double? price = 0.99,
  String formattedPrice = '£0.99',
  String currencyCode = 'GBP',
  String rawJson = '{}',
}) => SamsungPurchase(
  productId: productId,
  name: name,
  purchaseId: purchaseId,
  paymentId: paymentId,
  orderId: orderId,
  type: type,
  purchaseDate: purchaseDate,
  minorStatus: minorStatus,
  obfuscatedAccountId: obfuscatedAccountId,
  obfuscatedProfileId: obfuscatedProfileId,
  price: price,
  formattedPrice: formattedPrice,
  currencyCode: currencyCode,
  rawJson: rawJson,
);

void main() {
  group(SamsungIapFlutterPlatform, () {
    test('default instance throws until an implementation registers', () {
      final platform = SamsungIapFlutterPlatform.instance;

      expect(
        () => platform.initialize(
          mode: OperationMode.production,
          showErrorDialog: true,
        ),
        throwsUnimplementedError,
      );
      expect(platform.getGalaxyStoreStatus, throwsUnimplementedError);
      expect(() => platform.getProducts([]), throwsUnimplementedError);
      expect(
        () => platform.getOwnedProducts(OwnedProductFilter.all),
        throwsUnimplementedError,
      );
      expect(() => platform.purchase('coins_100'), throwsUnimplementedError);
    });

    test('accepts an instance that extends the base class', () {
      final platform = _ExtendsPlatform();
      SamsungIapFlutterPlatform.instance = platform;

      expect(SamsungIapFlutterPlatform.instance, same(platform));
    });

    test('rejects an instance that implements instead of extends', () {
      expect(
        () => SamsungIapFlutterPlatform.instance = _ImplementsPlatform(),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group(SamsungIapException, () {
    test('defaults to no dialog and no raw codes', () {
      const exception = SamsungIapException(
        SamsungIapErrorKind.notInitialized,
        message: 'call initialize first',
      );

      expect(exception.dialogShown, isFalse);
      expect(exception.code, isNull);
      expect(exception.detailCode, isNull);
      expect(exception.details, isNull);
    });

    test('toString carries the kind and codes for logs', () {
      const exception = SamsungIapException(
        SamsungIapErrorKind.alreadyOwned,
        message: 'Already purchased.',
        code: -1003,
        detailCode: 9224,
        details: 'IS9224/6050/NwCbCAxypi',
        dialogShown: true,
      );

      expect(
        exception.toString(),
        'SamsungIapException(alreadyOwned, code: -1003, detailCode: 9224, '
        'message: Already purchased.)',
      );
    });
  });

  group('models', () {
    test('products with the same fields are equal', () {
      expect(_product(), _product());
      expect(_product().hashCode, _product().hashCode);
    });

    test('products differing in any one field are not equal', () {
      const month = SubscriptionPeriod(count: 1, unit: PeriodUnit.month);
      final variants = [
        _product(id: 'coins_500'),
        _product(name: '500 coins'),
        _product(description: 'A pile of coins'),
        _product(type: SamsungProductType.subscription),
        _product(price: 1.99),
        _product(formattedPrice: '£1.99'),
        _product(currencyCode: 'EUR'),
        _product(currencySymbol: '€'),
        _product(subscriptionPeriod: month),
        _product(freeTrialDays: 7),
        _product(
          introductoryOffer: const IntroductoryOffer(
            price: null,
            formattedPrice: '',
            period: month,
            cycles: 1,
          ),
        ),
        _product(availableFrom: DateTime(2026)),
        _product(availableUntil: DateTime(2027)),
        _product(imageUrl: Uri.parse('https://example.com/a.png')),
        _product(downloadUrl: Uri.parse('https://example.com/a')),
        _product(rawJson: '{"mItemId":"coins_100"}'),
      ];

      for (final (index, variant) in variants.indexed) {
        expect(variant, isNot(_product()), reason: 'variant $index');
      }
    });

    test('subscription periods and offers compare by value', () {
      const month = SubscriptionPeriod(count: 1, unit: PeriodUnit.month);
      const offer = IntroductoryOffer(
        price: 0.99,
        formattedPrice: '£0.99',
        period: month,
        cycles: 3,
      );

      expect(month, const SubscriptionPeriod(count: 1, unit: PeriodUnit.month));
      expect(
        month,
        isNot(const SubscriptionPeriod(count: 1, unit: PeriodUnit.year)),
      );
      final sameOffer = IntroductoryOffer(
        price: 0.99,
        formattedPrice: '£0.99',
        period: month,
        cycles: int.parse('3'),
      );
      expect(offer, sameOffer);
      expect(offer.hashCode, sameOffer.hashCode);
      expect(
        offer,
        isNot(
          const IntroductoryOffer(
            price: 0.99,
            formattedPrice: '£0.99',
            period: month,
            cycles: 6,
          ),
        ),
      );
      expect(month.toString(), 'SubscriptionPeriod(1 month)');
      expect(offer.toString(), 'IntroductoryOffer(£0.99 x 3)');
      expect(_product().toString(), 'SamsungProduct(coins_100, £0.99)');
    });

    test('owned products with the same fields are equal', () {
      OwnedProduct full() => _owned(
        purchaseDate: DateTime(2026, 1, 1, 9),
        priceChange: _priceChange(startDate: DateTime(2026, 6)),
      );

      expect(full(), full());
      expect(full().hashCode, full().hashCode);
    });

    test('owned products differing in any one field are not equal', () {
      final variants = [
        _owned(productId: 'yearly'),
        _owned(name: 'Yearly'),
        _owned(purchaseId: 'd4e5f6'),
        _owned(paymentId: 'TPMTID20260202'),
        _owned(type: SamsungProductType.item),
        _owned(purchaseDate: DateTime(2026)),
        _owned(subscriptionEndDate: DateTime(2026, 2)),
        _owned(acknowledgedStatus: AcknowledgedStatus.notAcknowledged),
        _owned(priceChange: _priceChange()),
        _owned(obfuscatedAccountId: 'account'),
        _owned(obfuscatedProfileId: 'profile'),
        _owned(price: 8.99),
        _owned(formattedPrice: '£8.99'),
        _owned(currencyCode: 'EUR'),
        _owned(rawJson: '{"mItemId":"monthly"}'),
      ];

      for (final (index, variant) in variants.indexed) {
        expect(variant, isNot(_owned()), reason: 'variant $index');
      }
    });

    test('price changes differing in any one field are not equal', () {
      expect(_priceChange(), _priceChange());
      expect(_priceChange().hashCode, _priceChange().hashCode);
      final variants = [
        _priceChange(mode: PriceChangeMode.decrease),
        _priceChange(consented: true),
        _priceChange(startDate: DateTime(2026, 6)),
        _priceChange(originalPrice: 6.99),
        _priceChange(originalFormattedPrice: '£6.99'),
        _priceChange(newPrice: 9.99),
        _priceChange(newFormattedPrice: '£9.99'),
        _priceChange(
          period: const SubscriptionPeriod(count: 1, unit: PeriodUnit.month),
        ),
      ];

      for (final (index, variant) in variants.indexed) {
        expect(variant, isNot(_priceChange()), reason: 'variant $index');
      }
    });

    test('subscriptionDetailLink keeps the documented host casing', () {
      expect(
        _owned().subscriptionDetailLink,
        'samsungapps://SubscriptionDetail?purchaseId=a1b2c3',
      );
      expect(
        _owned(purchaseId: 'a&b c').subscriptionDetailLink,
        'samsungapps://SubscriptionDetail?purchaseId=a%26b+c',
      );
    });

    test('purchases with the same fields are equal', () {
      SamsungPurchase full() => _purchase(
        purchaseDate: DateTime(2026, 1, 1, 9),
        obfuscatedAccountId: 'account',
      );

      expect(full(), full());
      expect(full().hashCode, full().hashCode);
    });

    test('purchases differing in any one field are not equal', () {
      final variants = [
        _purchase(productId: 'coins_500'),
        _purchase(name: '500 coins'),
        _purchase(purchaseId: 'd4e5f6'),
        _purchase(paymentId: 'TPMTID20260202'),
        _purchase(orderId: 'S20260202KRA7654321'),
        _purchase(type: SamsungProductType.subscription),
        _purchase(purchaseDate: DateTime(2026)),
        _purchase(minorStatus: MinorStatus.minor),
        _purchase(obfuscatedAccountId: 'account'),
        _purchase(obfuscatedProfileId: 'profile'),
        _purchase(price: 1.99),
        _purchase(formattedPrice: '£1.99'),
        _purchase(currencyCode: 'EUR'),
        _purchase(rawJson: '{"mItemId":"coins_100"}'),
      ];

      for (final (index, variant) in variants.indexed) {
        expect(variant, isNot(_purchase()), reason: 'variant $index');
      }
    });

    test('a purchase describes itself with its IDs', () {
      expect(
        _purchase().toString(),
        'SamsungPurchase(coins_100, a1b2c3, S20260101KRA1234567)',
      );
    });

    test('owned products and price changes describe themselves', () {
      expect(
        _owned().toString(),
        'OwnedProduct(monthly, a1b2c3, acknowledged)',
      );
      expect(
        _priceChange().toString(),
        'SubscriptionPriceChange(increaseConsentRequired, '
        '£7.99 -> £8.99, consented: false)',
      );
    });
  });
}
