import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samsung_iap_flutter_android/samsung_iap_flutter_android.dart';
import 'package:samsung_iap_flutter_android/src/messages.g.dart';
import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

class _MockHostApi extends Mock implements SamsungIapHostApi;

PlatformProduct _wire({
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

PlatformSubscriptionPriceChange _priceChangeWire({
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

PlatformOwnedProduct _ownedWire({
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

Matcher _throwsKind(SamsungIapErrorKind kind) =>
    throwsA(isA<SamsungIapException>().having((e) => e.kind, 'kind', kind));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockHostApi api;
  late SamsungIapFlutterAndroid plugin;

  setUpAll(() {
    registerFallbackValue(PlatformOperationMode.production);
    registerFallbackValue(PlatformOwnedProductFilter.all);
  });

  setUp(() {
    api = _MockHostApi();
    plugin = SamsungIapFlutterAndroid(api: api);
    when(() => api.initialize(any(), any())).thenAnswer((_) async {});
  });

  Future<void> initialize() =>
      plugin.initialize(mode: OperationMode.test, showErrorDialog: true);

  test('can be registered', () {
    SamsungIapFlutterAndroid.registerWith();

    expect(SamsungIapFlutterPlatform.instance, isA<SamsungIapFlutterAndroid>());
  });

  test('initialize sends every operation mode and the dialog flag', () async {
    final modes = {
      OperationMode.production: PlatformOperationMode.production,
      OperationMode.test: PlatformOperationMode.test,
      OperationMode.testFailure: PlatformOperationMode.testFailure,
    };
    for (final MapEntry(key: mode, value: wire) in modes.entries) {
      await plugin.initialize(mode: mode, showErrorDialog: false);

      verify(() => api.initialize(wire, false)).called(1);
    }
  });

  group('getGalaxyStoreStatus', () {
    test('maps every status, without initialize', () async {
      final statuses = {
        PlatformStoreStatus.available: GalaxyStoreStatus.available,
        PlatformStoreStatus.notInstalled: GalaxyStoreStatus.notInstalled,
        PlatformStoreStatus.disabled: GalaxyStoreStatus.disabled,
        PlatformStoreStatus.invalid: GalaxyStoreStatus.invalid,
      };
      for (final MapEntry(key: wire, value: status) in statuses.entries) {
        when(api.getStoreStatus).thenAnswer((_) async => wire);

        expect(await plugin.getGalaxyStoreStatus(), status);
      }
      verifyNever(() => api.initialize(any(), any()));
    });

    test('answers while a getProducts call is still waiting', () async {
      final pending = Completer<List<PlatformProduct>>();
      when(() => api.getProductsDetails(any()))
          .thenAnswer((_) => pending.future);
      when(api.getStoreStatus)
          .thenAnswer((_) async => PlatformStoreStatus.available);

      final products = plugin.getProducts([]);

      expect(await plugin.getGalaxyStoreStatus(), GalaxyStoreStatus.available);
      pending.complete([]);
      await products;
    });

    test('maps a bridge error', () async {
      when(api.getStoreStatus).thenThrow(PlatformException(code: 'boom'));

      await expectLater(plugin.getGalaxyStoreStatus(), _throwsKind(.unknown));
    });
  });

  group('getProducts', () {
    setUp(initialize);

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
          _wire(
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
      when(
        () => api.getProductsDetails(any()),
      ).thenAnswer((_) async => [_wire(itemPrice: double.nan, type: 'bundle')]);

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
        _wire(
          tieredSubscriptionYN: 'N',
          tieredSubscriptionDurationUnit: 'MONTH',
          tieredSubscriptionDurationMultiplier: '1',
          tieredSubscriptionCount: '3',
        ),
        _wire(
          tieredSubscriptionYN: 'Y',
          tieredSubscriptionDurationUnit: 'MONTH',
          tieredSubscriptionDurationMultiplier: '1',
        ),
        _wire(tieredSubscriptionYN: 'Y', tieredSubscriptionCount: '3'),
      ];
      when(() => api.getProductsDetails(any())).thenAnswer((_) async => offers);

      final products = await plugin.getProducts([]);

      expect(products.map((p) => p.introductoryOffer), [null, null, null]);
    });

    test('keeps an intro offer whose price is not finite', () async {
      when(() => api.getProductsDetails(any())).thenAnswer(
        (_) async => [
          _wire(
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
  });

  group('getOwnedProducts', () {
    setUp(initialize);

    void answerOwned(List<PlatformOwnedProduct> owned) =>
        when(() => api.getOwnedList(any())).thenAnswer((_) async => owned);

    test('sends every filter', () async {
      answerOwned([]);
      final filters = {
        OwnedProductFilter.item: PlatformOwnedProductFilter.item,
        OwnedProductFilter.subscription:
            PlatformOwnedProductFilter.subscription,
        OwnedProductFilter.all: PlatformOwnedProductFilter.all,
      };
      for (final MapEntry(key: filter, value: wire) in filters.entries) {
        await plugin.getOwnedProducts(filter);

        verify(() => api.getOwnedList(wire)).called(1);
      }
    });

    test('maps a subscription with a pending price change', () async {
      answerOwned([_ownedWire(subscriptionPriceChange: _priceChangeWire())]);

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
        _ownedWire(
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

    test('reads the epoch the SDK writes for a missing date as null', () async {
      final epoch = DateTime.fromMillisecondsSinceEpoch(0);
      String two(int n) => n.toString().padLeft(2, '0');
      final formatted =
          '${epoch.year}-${two(epoch.month)}-${two(epoch.day)} '
          '${two(epoch.hour)}:${two(epoch.minute)}:${two(epoch.second)}';
      answerOwned([_ownedWire(purchaseDate: formatted)]);

      final owned = (await plugin.getOwnedProducts(.all)).single;

      expect(owned.purchaseDate, isNull);
    });

    test('maps the consent flag, reading a missing one as no', () async {
      final flags = <bool?, bool>{true: true, false: false, null: false};
      for (final MapEntry(key: wire, value: consented) in flags.entries) {
        answerOwned([
          _ownedWire(
            subscriptionPriceChange: _priceChangeWire(isConsented: wire),
          ),
        ]);

        final owned = (await plugin.getOwnedProducts(.subscription)).single;

        expect(owned.priceChange?.consented, consented, reason: '$wire');
      }
    });

    test('maps a price change Samsung could not fully parse', () async {
      answerOwned([
        _ownedWire(
          subscriptionPriceChange: _priceChangeWire(
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

    test('waits for an earlier call and does not block a later one', () async {
      final products = Completer<List<PlatformProduct>>();
      when(() => api.getProductsDetails(any()))
          .thenAnswer((_) => products.future);
      when(() => api.getOwnedList(PlatformOwnedProductFilter.item))
          .thenThrow(PlatformException(code: 'timeout'));
      when(() => api.getOwnedList(PlatformOwnedProductFilter.all))
          .thenAnswer((_) async => [_ownedWire()]);

      final first = plugin.getProducts([]);
      final failed = plugin.getOwnedProducts(.item);
      final next = plugin.getOwnedProducts(.all);
      await pumpEventQueue();

      verifyNever(() => api.getOwnedList(any()));
      products.complete([]);
      await first;
      await expectLater(failed, _throwsKind(.network));
      expect((await next).single.purchaseId, 'a1b2c3');
    });

    test('maps the bridge errors of the call', () async {
      final kinds = {
        'store_unavailable': SamsungIapErrorKind.storeUnavailable,
        'not_initialized': SamsungIapErrorKind.notInitialized,
        'not_sent': SamsungIapErrorKind.busy,
      };
      for (final MapEntry(key: code, value: kind) in kinds.entries) {
        when(() => api.getOwnedList(any()))
            .thenThrow(PlatformException(code: code));

        await expectLater(
          plugin.getOwnedProducts(.all),
          _throwsKind(kind),
          reason: code,
        );
      }
    });
  });

  group('errors', () {
    setUp(initialize);

    Future<SamsungIapException> failWith(PlatformException error) async {
      when(() => api.getProductsDetails(any())).thenThrow(error);
      try {
        await plugin.getProducts([]);
      } on SamsungIapException catch (e) {
        return e;
      }
      fail('getProducts did not throw');
    }

    PlatformException sdkError(int code, {String? details = 'IS9224/6050/x'}) =>
        PlatformException(
          code: 'sdk',
          message: 'Samsung says no.',
          details: {
            'errorCode': code,
            'errorDetails': details,
            'dialogShown': true,
          },
        );

    test('maps every Samsung response code to its kind', () async {
      final kinds = {
        1: SamsungIapErrorKind.userCanceled,
        -1000: SamsungIapErrorKind.initializationFailed,
        -1001: SamsungIapErrorKind.storeUpdateRequired,
        -1002: SamsungIapErrorKind.general,
        -1003: SamsungIapErrorKind.alreadyOwned,
        -1004: SamsungIapErrorKind.unknown,
        -1005: SamsungIapErrorKind.productNotFound,
        -1006: SamsungIapErrorKind.purchaseResultUnknown,
        -1007: SamsungIapErrorKind.productNotFound,
        -1008: SamsungIapErrorKind.network,
        -1009: SamsungIapErrorKind.network,
        -1010: SamsungIapErrorKind.network,
        -1011: SamsungIapErrorKind.network,
        -1012: SamsungIapErrorKind.notAvailableInCountry,
        -1013: SamsungIapErrorKind.notAvailableInCountry,
        -1014: SamsungIapErrorKind.accountNotSignedIn,
        -1015: SamsungIapErrorKind.accountNotSignedIn,
        -9999: SamsungIapErrorKind.unknown,
      };
      for (final MapEntry(key: code, value: kind) in kinds.entries) {
        final e = await failWith(sdkError(code));

        expect(e.kind, kind, reason: '$code');
        expect(e.code, code);
      }
    });

    test('keeps the raw Samsung fields', () async {
      final e = await failWith(sdkError(-1003));

      expect(e.message, 'Samsung says no.');
      expect(e.details, 'IS9224/6050/x');
      expect(e.detailCode, 9224);
      expect(e.dialogShown, isTrue);
    });

    test('parses the detail code before the first slash', () async {
      final detailCodes = <String?, int?>{
        'IS9224/6050/NwCbCAxypi': 9224,
        '100010': 100010,
        'abc/123': null,
        '': null,
        null: null,
      };
      for (final MapEntry(key: details, value: code) in detailCodes.entries) {
        final e = await failWith(sdkError(-1002, details: details));

        expect(e.detailCode, code, reason: '$details');
      }
    });

    test('maps the bridge codes to their kinds', () async {
      final kinds = {
        'not_sent': SamsungIapErrorKind.busy,
        'not_initialized': SamsungIapErrorKind.notInitialized,
        'store_unavailable': SamsungIapErrorKind.storeUnavailable,
        'store_update_required': SamsungIapErrorKind.storeUpdateRequired,
        'timeout': SamsungIapErrorKind.network,
        'IllegalStateException': SamsungIapErrorKind.unknown,
      };
      for (final MapEntry(key: code, value: kind) in kinds.entries) {
        final e = await failWith(PlatformException(code: code));

        expect(e.kind, kind, reason: code);
        expect(e.code, isNull);
        expect(e.dialogShown, isFalse);
      }
    });

    test('keeps the store status of store_unavailable', () async {
      final e = await failWith(
        PlatformException(
          code: 'store_unavailable',
          message: 'Galaxy Store is unusable: disabled',
          details: 'disabled',
        ),
      );

      expect(e.message, 'Galaxy Store is unusable: disabled');
      expect(e.details, 'disabled');
    });

    test('treats a malformed sdk error as unknown', () async {
      final e = await failWith(
        PlatformException(code: 'sdk', details: ['-1003']),
      );

      expect(e.kind, SamsungIapErrorKind.unknown);
      expect(e.details, isNull);
    });
  });

  group('queue', () {
    test('sends a call only after the previous one settled', () async {
      final first = Completer<List<PlatformProduct>>();
      when(() => api.getProductsDetails('first'))
          .thenAnswer((_) => first.future);
      when(() => api.getProductsDetails('second')).thenAnswer((_) async => []);

      final firstProducts = plugin.getProducts(['first']);
      final secondProducts = plugin.getProducts(['second']);
      await pumpEventQueue();

      verifyNever(() => api.getProductsDetails('second'));

      first.complete([]);
      await firstProducts;
      await secondProducts;
      verify(() => api.getProductsDetails('second')).called(1);
    });

    test('a failed call does not block the next one', () async {
      when(() => api.getProductsDetails('first'))
          .thenThrow(PlatformException(code: 'not_sent'));
      when(() => api.getProductsDetails('second'))
          .thenAnswer((_) async => [_wire(itemId: 'second')]);

      final failed = plugin.getProducts(['first']);
      final next = plugin.getProducts(['second']);

      await expectLater(failed, _throwsKind(.busy));
      expect((await next).single.id, 'second');
    });

    test('initialize runs before a call made without awaiting it', () async {
      when(() => api.getProductsDetails(any())).thenAnswer((_) async => []);
      final initialized = Completer<void>();
      when(() => api.initialize(any(), any()))
          .thenAnswer((_) => initialized.future);

      unawaited(initialize());
      final products = plugin.getProducts([]);
      await pumpEventQueue();

      verifyNever(() => api.getProductsDetails(any()));
      initialized.complete();
      await products;
    });
  });
}
