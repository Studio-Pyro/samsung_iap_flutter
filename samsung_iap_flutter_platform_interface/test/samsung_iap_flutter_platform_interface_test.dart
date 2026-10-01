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
  });
}
