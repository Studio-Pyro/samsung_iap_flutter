import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:samsung_iap_flutter/samsung_iap_flutter.dart';
import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

class _MockPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements SamsungIapFlutterPlatform;

const _product = SamsungProduct(
  id: 'coins_100',
  name: '100 coins',
  description: '',
  type: SamsungProductType.item,
  price: 0.99,
  formattedPrice: '£0.99',
  currencyCode: 'GBP',
  currencySymbol: '£',
  subscriptionPeriod: null,
  freeTrialDays: null,
  introductoryOffer: null,
  availableFrom: null,
  availableUntil: null,
  imageUrl: null,
  downloadUrl: null,
  rawJson: '{}',
);

void main() {
  late _MockPlatform platform;
  const iap = SamsungIap();

  setUpAll(() {
    registerFallbackValue(OperationMode.production);
    registerFallbackValue(OwnedProductFilter.all);
  });

  setUp(() {
    platform = _MockPlatform();
    SamsungIapFlutterPlatform.instance = platform;
  });

  group('initialize', () {
    setUp(() {
      when(
        () => platform.initialize(
          mode: any(named: 'mode'),
          showErrorDialog: any(named: 'showErrorDialog'),
        ),
      ).thenAnswer((_) async {});
    });

    test('defaults to production with Samsung dialogs', () async {
      await iap.initialize();

      verify(
        () => platform.initialize(
          mode: OperationMode.production,
          showErrorDialog: true,
        ),
      ).called(1);
    });

    test('passes an explicit mode and dialog flag', () async {
      await iap.initialize(mode: OperationMode.test, showErrorDialog: false);

      verify(
        () => platform.initialize(
          mode: OperationMode.test,
          showErrorDialog: false,
        ),
      ).called(1);
    });
  });

  test('getGalaxyStoreStatus returns the platform status', () async {
    when(platform.getGalaxyStoreStatus)
        .thenAnswer((_) async => GalaxyStoreStatus.disabled);

    expect(await iap.getGalaxyStoreStatus(), GalaxyStoreStatus.disabled);
  });

  group('getProducts', () {
    setUp(() {
      when(() => platform.getProducts(any()))
          .thenAnswer((_) async => [_product]);
    });

    test('asks for every product by default', () async {
      expect(await iap.getProducts(), [_product]);

      verify(() => platform.getProducts([])).called(1);
    });

    test('passes the requested IDs', () async {
      await iap.getProducts(['coins_100', 'monthly']);

      verify(() => platform.getProducts(['coins_100', 'monthly'])).called(1);
    });

    test('rejects an empty or comma-joined ID before the platform', () async {
      for (final ids in [
        [''],
        ['coins_100', '  '],
        ['coins_100,monthly'],
      ]) {
        await expectLater(
          iap.getProducts(ids),
          throwsA(
            isA<SamsungIapException>().having(
              (e) => e.kind,
              'kind',
              SamsungIapErrorKind.invalidArgument,
            ),
          ),
          reason: '$ids',
        );
      }
      verifyNever(() => platform.getProducts(any()));
    });
  });

  group('getOwnedProducts', () {
    const owned = OwnedProduct(
      productId: 'coins_100',
      name: '100 coins',
      purchaseId: 'a1b2c3',
      paymentId: 'TPMTID20260101',
      type: SamsungProductType.item,
      purchaseDate: null,
      subscriptionEndDate: null,
      acknowledgedStatus: AcknowledgedStatus.notAcknowledged,
      priceChange: null,
      obfuscatedAccountId: null,
      obfuscatedProfileId: null,
      price: 0.99,
      formattedPrice: '£0.99',
      currencyCode: 'GBP',
      rawJson: '{}',
    );

    setUp(() {
      when(() => platform.getOwnedProducts(any()))
          .thenAnswer((_) async => [owned]);
    });

    test('asks for every owned product by default', () async {
      expect(await iap.getOwnedProducts(), [owned]);

      verify(() => platform.getOwnedProducts(OwnedProductFilter.all)).called(1);
    });

    test('passes the filter', () async {
      for (final filter in OwnedProductFilter.values) {
        await iap.getOwnedProducts(filter: filter);

        verify(() => platform.getOwnedProducts(filter)).called(1);
      }
    });
  });

  group('purchase', () {
    const purchase = SamsungPurchase(
      productId: 'coins_100',
      name: '100 coins',
      purchaseId: 'a1b2c3',
      paymentId: 'TPMTID20260101',
      orderId: 'S20260101KRA1234567',
      type: SamsungProductType.item,
      purchaseDate: null,
      minorStatus: MinorStatus.notMinor,
      obfuscatedAccountId: null,
      obfuscatedProfileId: null,
      price: 0.99,
      formattedPrice: '£0.99',
      currencyCode: 'GBP',
      rawJson: '{}',
    );

    void verifyNeverSent() => verifyNever(
      () => platform.purchase(
        any(),
        obfuscatedAccountId: any(named: 'obfuscatedAccountId'),
        obfuscatedProfileId: any(named: 'obfuscatedProfileId'),
      ),
    );

    setUp(() {
      when(
        () => platform.purchase(
          any(),
          obfuscatedAccountId: any(named: 'obfuscatedAccountId'),
          obfuscatedProfileId: any(named: 'obfuscatedProfileId'),
        ),
      ).thenAnswer((_) async => purchase);
    });

    test('returns the platform purchase without obfuscated IDs', () async {
      expect(await iap.purchase('coins_100'), purchase);

      verify(() => platform.purchase('coins_100')).called(1);
    });

    test('passes valid obfuscated IDs unchanged', () async {
      final accepted = <(String?, String?)>[
        ('a' * 64, null),
        ('é' * 32, 'ü' * 32),
        ('😀' * 16, null),
        ('user@localhost', null),
        ('5f4dcc3b5aa765d61d8327deb882cf99', 'profile-1'),
      ];
      for (final (account, profile) in accepted) {
        await iap.purchase(
          'coins_100',
          obfuscatedAccountId: account,
          obfuscatedProfileId: profile,
        );

        verify(
          () => platform.purchase(
            'coins_100',
            obfuscatedAccountId: account,
            obfuscatedProfileId: profile,
          ),
        ).called(1);
      }
    });

    test('rejects invalid arguments before the platform', () async {
      final rejected = <String, (String, String?, String?)>{
        'empty product ID': ('', null, null),
        'blank product ID': ('  ', null, null),
        '65 ASCII bytes': ('coins_100', 'a' * 65, null),
        '33 two-byte characters': ('coins_100', 'é' * 33, null),
        '17 four-byte characters': ('coins_100', '😀' * 17, null),
        'a long profile ID': ('coins_100', 'account', 'ü' * 33),
        'an email account ID': ('coins_100', 'jo.doe@example.com', null),
        'an email profile ID': ('coins_100', 'account', 'jo@mail.example.co'),
        'a profile ID alone': ('coins_100', null, 'profile'),
        'an empty account ID': ('coins_100', '', null),
        'an empty profile ID': ('coins_100', 'account', ''),
      };
      for (final MapEntry(key: reason, value: args) in rejected.entries) {
        final (productId, account, profile) = args;

        await expectLater(
          iap.purchase(
            productId,
            obfuscatedAccountId: account,
            obfuscatedProfileId: profile,
          ),
          throwsA(
            isA<SamsungIapException>().having(
              (e) => e.kind,
              'kind',
              SamsungIapErrorKind.invalidArgument,
            ),
          ),
          reason: reason,
        );
      }
      verifyNeverSent();
    });

    test('names the broken rule in the message', () async {
      await expectLater(
        iap.purchase(' '),
        throwsA(
          isA<SamsungIapException>().having(
            (e) => e.message,
            'message',
            'The product ID is empty.',
          ),
        ),
      );
      final messages = {
        ('a' * 65, null):
            'The obfuscated account ID is longer than 64 '
            'UTF-8 bytes.',
        ('account', 'a@b.io'):
            'The obfuscated profile ID looks like an '
            'email address.',
        (null, 'profile'):
            'An obfuscated profile ID needs an obfuscated '
            'account ID.',
        ('', null):
            'The obfuscated account ID is empty; pass null to omit '
            'it.',
      };
      for (final MapEntry(key: (account, profile), value: message)
          in messages.entries) {
        await expectLater(
          iap.purchase(
            'coins_100',
            obfuscatedAccountId: account,
            obfuscatedProfileId: profile,
          ),
          throwsA(
            isA<SamsungIapException>().having(
              (e) => e.message,
              'message',
              message,
            ),
          ),
        );
      }
    });
  });

  final ackCalls = {
    'consume': (
      platformCall: (List<String> ids) => platform.consume(ids),
      call: iap.consume,
    ),
    'acknowledge': (
      platformCall: (List<String> ids) => platform.acknowledge(ids),
      call: iap.acknowledge,
    ),
  };
  for (final MapEntry(key: name, value: ack) in ackCalls.entries) {
    group(name, () {
      const results = [
        PurchaseAckResult(
          purchaseId: 'a1b2c3',
          status: AckStatus.success,
          statusCode: 0,
          message: 'success',
        ),
        PurchaseAckResult(
          purchaseId: 'bogus',
          status: AckStatus.invalidPurchaseId,
          statusCode: 1,
          message: 'invalid purchaseId',
        ),
      ];

      setUp(() {
        when(() => ack.platformCall(any())).thenAnswer((_) async => results);
      });

      test('returns the per-purchase results of the platform', () async {
        expect(await ack.call(['a1b2c3', 'bogus']), results);

        verify(() => ack.platformCall(['a1b2c3', 'bogus'])).called(1);
      });

      test('rejects invalid purchase IDs before the platform', () async {
        final rejected = {
          'no IDs': <String>[],
          'an empty ID': ['a1b2c3', ''],
          'a blank ID': ['  '],
          'a comma-joined ID': ['a1b2c3,d4e5f6'],
        };
        for (final MapEntry(key: reason, value: ids) in rejected.entries) {
          await expectLater(
            ack.call(ids),
            throwsA(
              isA<SamsungIapException>().having(
                (e) => e.kind,
                'kind',
                SamsungIapErrorKind.invalidArgument,
              ),
            ),
            reason: reason,
          );
        }
        verifyNever(() => ack.platformCall(any()));
      });

      test('explains the rejection in the message', () async {
        await expectLater(
          ack.call([]),
          throwsA(
            isA<SamsungIapException>().having(
              (e) => e.message,
              'message',
              'The list of purchase IDs is empty.',
            ),
          ),
        );
        await expectLater(
          ack.call(['a,b']),
          throwsA(
            isA<SamsungIapException>().having(
              (e) => e.message,
              'message',
              'Invalid purchase ID: "a,b".',
            ),
          ),
        );
      });
    });
  }

  group('changeSubscriptionPlan', () {
    const upgraded = SamsungPurchase(
      productId: 'monthly_premium',
      name: 'Premium',
      purchaseId: 'd4e5f6',
      paymentId: 'TPMTID20260201',
      orderId: 'S20260201KRA1234567',
      type: SamsungProductType.subscription,
      purchaseDate: null,
      minorStatus: MinorStatus.notMinor,
      obfuscatedAccountId: 'account',
      obfuscatedProfileId: null,
      price: 9.99,
      formattedPrice: '£9.99',
      currencyCode: 'GBP',
      rawJson: '{}',
    );

    Future<SamsungPurchase> platformChange() => platform.changeSubscriptionPlan(
      fromProductId: any(named: 'fromProductId'),
      toProductId: any(named: 'toProductId'),
      prorationMode: any(named: 'prorationMode'),
      obfuscatedAccountId: any(named: 'obfuscatedAccountId'),
      obfuscatedProfileId: any(named: 'obfuscatedProfileId'),
    );

    Matcher throwsInvalidArgument(String message) => throwsA(
      isA<SamsungIapException>()
          .having((e) => e.kind, 'kind', SamsungIapErrorKind.invalidArgument)
          .having((e) => e.message, 'message', message),
    );

    setUpAll(() => registerFallbackValue(ProrationMode.deferred));

    setUp(() {
      when(platformChange).thenAnswer((_) async => upgraded);
    });

    test('passes every proration mode and returns the new purchase', () async {
      for (final mode in ProrationMode.values) {
        expect(
          await iap.changeSubscriptionPlan(
            fromProductId: 'monthly',
            toProductId: 'monthly_premium',
            prorationMode: mode,
          ),
          upgraded,
        );

        verify(
          () => platform.changeSubscriptionPlan(
            fromProductId: 'monthly',
            toProductId: 'monthly_premium',
            prorationMode: mode,
          ),
        ).called(1);
      }
    });

    test('passes valid obfuscated IDs unchanged', () async {
      await iap.changeSubscriptionPlan(
        fromProductId: 'monthly',
        toProductId: 'monthly_premium',
        prorationMode: ProrationMode.instantProratedDate,
        obfuscatedAccountId: 'a' * 64,
        obfuscatedProfileId: 'profile',
      );

      verify(
        () => platform.changeSubscriptionPlan(
          fromProductId: 'monthly',
          toProductId: 'monthly_premium',
          prorationMode: ProrationMode.instantProratedDate,
          obfuscatedAccountId: 'a' * 64,
          obfuscatedProfileId: 'profile',
        ),
      ).called(1);
    });

    test('rejects invalid arguments before the platform', () async {
      final rejected = <(String, String, String?, String?), String>{
        ('', 'monthly_premium', null, null): 'The from product ID is empty.',
        ('monthly', '  ', null, null): 'The to product ID is empty.',
        ('monthly', 'monthly_premium', 'a' * 65, null):
            'The obfuscated account ID is longer than 64 UTF-8 bytes.',
        ('monthly', 'monthly_premium', 'account', 'jo@example.com'):
            'The obfuscated profile ID looks like an email address.',
        ('monthly', 'monthly_premium', null, 'profile'):
            'An obfuscated profile ID needs an obfuscated account ID.',
        ('monthly', 'monthly_premium', '', null):
            'The obfuscated account ID is empty; pass null to omit it.',
      };
      for (final MapEntry(key: (from, to, account, profile), value: message)
          in rejected.entries) {
        await expectLater(
          iap.changeSubscriptionPlan(
            fromProductId: from,
            toProductId: to,
            prorationMode: ProrationMode.instantProratedDate,
            obfuscatedAccountId: account,
            obfuscatedProfileId: profile,
          ),
          throwsInvalidArgument(message),
        );
      }
      verifyNever(platformChange);
    });

    test('sends a change to the same product', () async {
      await iap.changeSubscriptionPlan(
        fromProductId: 'monthly',
        toProductId: 'monthly',
        prorationMode: ProrationMode.deferred,
      );

      verify(
        () => platform.changeSubscriptionPlan(
          fromProductId: 'monthly',
          toProductId: 'monthly',
          prorationMode: ProrationMode.deferred,
        ),
      ).called(1);
    });
  });
}
