import 'dart:async';

import 'package:fake_async/fake_async.dart';
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

Matcher _throwsKind(SamsungIapErrorKind kind) =>
    throwsA(isA<SamsungIapException>().having((e) => e.kind, 'kind', kind));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockHostApi api;
  late SamsungIapFlutterAndroid plugin;

  setUpAll(() {
    registerFallbackValue(PlatformOperationMode.production);
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

  test('initialize in any mode sends it and unlocks the other calls', () async {
    final modes = {
      OperationMode.production: PlatformOperationMode.production,
      OperationMode.test: PlatformOperationMode.test,
      OperationMode.testFailure: PlatformOperationMode.testFailure,
    };
    when(api.getStoreStatus)
        .thenAnswer((_) async => PlatformStoreStatus.available);
    for (final MapEntry(key: mode, value: wire) in modes.entries) {
      final plugin = SamsungIapFlutterAndroid(api: api);
      await plugin.initialize(mode: mode, showErrorDialog: false);

      verify(() => api.initialize(wire, false)).called(1);
      expect(
        await plugin.getGalaxyStoreStatus(),
        GalaxyStoreStatus.available,
        reason: 'initialized in $mode',
      );
    }
  });

  test('getGalaxyStoreStatus maps every status', () async {
    await initialize();
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

    test('keeps an introductory offer without a numeric price', () async {
      when(() => api.getProductsDetails(any())).thenAnswer(
        (_) async => [
          _wire(
            tieredSubscriptionYN: 'Y',
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
          message: 'Galaxy Store is unusable: DISABLED',
          details: 'DISABLED',
        ),
      );

      expect(e.message, 'Galaxy Store is unusable: DISABLED');
      expect(e.details, 'DISABLED');
    });

    test('treats a malformed sdk error as unknown', () async {
      final e = await failWith(
        PlatformException(code: 'sdk', details: ['-1003']),
      );

      expect(e.kind, SamsungIapErrorKind.unknown);
      expect(e.details, isNull);
    });
  });

  group('before initialize', () {
    test(
      'every call fails with notInitialized without reaching Samsung',
      () async {
        await expectLater(
          plugin.getGalaxyStoreStatus(),
          _throwsKind(.notInitialized),
        );
        await expectLater(plugin.getProducts([]), _throwsKind(.notInitialized));
        verifyNever(api.getStoreStatus);
        verifyNever(() => api.getProductsDetails(any()));
      },
    );

    test('a failed initialize leaves the plugin uninitialized', () async {
      when(() => api.initialize(any(), any()))
          .thenThrow(PlatformException(code: 'IllegalStateException'));

      await expectLater(initialize(), _throwsKind(.unknown));
      await expectLater(plugin.getProducts([]), _throwsKind(.notInitialized));
    });
  });

  group('queue', () {
    setUp(initialize);

    test('sends a call only after the previous one settled', () async {
      final first = Completer<List<PlatformProduct>>();
      when(() => api.getProductsDetails('first'))
          .thenAnswer((_) => first.future);
      when(() => api.getStoreStatus())
          .thenAnswer((_) async => PlatformStoreStatus.available);

      final products = plugin.getProducts(['first']);
      final status = plugin.getGalaxyStoreStatus();
      await pumpEventQueue();

      verifyNever(api.getStoreStatus);

      first.complete([]);
      await products;
      expect(await status, GalaxyStoreStatus.available);
    });

    test('a failed call does not block the next one', () async {
      when(() => api.getProductsDetails(any()))
          .thenThrow(PlatformException(code: 'not_sent'));
      when(() => api.getStoreStatus())
          .thenAnswer((_) async => PlatformStoreStatus.disabled);

      final failed = plugin.getProducts([]);
      final status = plugin.getGalaxyStoreStatus();

      await expectLater(failed, _throwsKind(.busy));
      expect(await status, GalaxyStoreStatus.disabled);
    });
  });

  test('getProducts times out after 30s and ignores the late answer', () {
    fakeAsync((async) {
      // The queue's first future must belong to the fake zone.
      plugin = SamsungIapFlutterAndroid(api: api);
      final answer = Completer<List<PlatformProduct>>();
      when(() => api.getProductsDetails(any()))
          .thenAnswer((_) => answer.future);
      when(() => api.getStoreStatus())
          .thenAnswer((_) async => PlatformStoreStatus.available);
      unawaited(initialize());
      async.flushMicrotasks();

      SamsungIapException? error;
      unawaited(
        plugin.getProducts([]).catchError((Object e) {
          error = e as SamsungIapException;
          return <SamsungProduct>[];
        }),
      );
      GalaxyStoreStatus? status;
      unawaited(plugin.getGalaxyStoreStatus().then((s) => status = s));

      async.elapse(const Duration(seconds: 29));
      expect(error, isNull);
      expect(status, isNull);

      async.elapse(const Duration(seconds: 1));
      expect(error?.kind, SamsungIapErrorKind.unknown);
      expect(error?.message, contains('30s'));
      expect(status, GalaxyStoreStatus.available);

      answer.completeError(PlatformException(code: 'sdk'));
      async.flushMicrotasks();
    });
  });
}
