import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samsung_iap_flutter_android/samsung_iap_flutter_android.dart';
import 'package:samsung_iap_flutter_android/src/messages.g.dart';
import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

import 'helpers.dart';

void main() {
  late MockHostApi api;
  late SamsungIapFlutterAndroid plugin;

  setUp(() async {
    (api, plugin) = newPlugin();
    await initializeForTest(plugin);
    when(() => api.changeSubscriptionPlan(any(), any(), any(), any(), any()))
        .thenAnswer((_) async => purchaseWire());
  });

  Future<SamsungPurchase> change({
    ProrationMode mode = ProrationMode.instantProratedDate,
    String? obfuscatedAccountId,
    String? obfuscatedProfileId,
  }) => plugin.changeSubscriptionPlan(
    fromProductId: 'monthly',
    toProductId: 'monthly_premium',
    prorationMode: mode,
    obfuscatedAccountId: obfuscatedAccountId,
    obfuscatedProfileId: obfuscatedProfileId,
  );

  test('sends both product IDs and the obfuscated IDs', () async {
    await change(obfuscatedAccountId: 'account', obfuscatedProfileId: 'p');
    await change();

    verify(
      () => api.changeSubscriptionPlan(
        'monthly',
        'monthly_premium',
        PlatformProrationMode.instantProratedDate,
        'account',
        'p',
      ),
    ).called(1);
    verify(
      () => api.changeSubscriptionPlan(
        'monthly',
        'monthly_premium',
        PlatformProrationMode.instantProratedDate,
        null,
        null,
      ),
    ).called(1);
  });

  test('sends each proration mode as its wire form', () async {
    final expected = {
      ProrationMode.instantProratedDate:
          PlatformProrationMode.instantProratedDate,
      ProrationMode.instantProratedCharge:
          PlatformProrationMode.instantProratedCharge,
      ProrationMode.instantNoProration:
          PlatformProrationMode.instantNoProration,
      ProrationMode.deferred: PlatformProrationMode.deferred,
    };
    expect(expected.keys, unorderedEquals(ProrationMode.values));

    for (final MapEntry(key: mode, value: wire) in expected.entries) {
      await change(mode: mode);

      verify(() => api.changeSubscriptionPlan(any(), any(), wire, any(), any()))
          .called(1);
    }
  });

  test('maps the new purchase with every field', () async {
    expect(
      await change(),
      SamsungPurchase(
        productId: 'coins_100',
        name: '100 coins',
        purchaseId: 'a1b2c3',
        paymentId: 'TPMTID20260101',
        orderId: 'S20260101KRA1234567',
        type: SamsungProductType.item,
        purchaseDate: DateTime(2026, 1, 1, 9),
        minorStatus: MinorStatus.notMinor,
        obfuscatedAccountId: 'account',
        obfuscatedProfileId: 'profile',
        price: 0.99,
        formattedPrice: '£0.99',
        currencyCode: 'GBP',
        rawJson: '{"mPurchaseId":"a1b2c3"}',
      ),
    );
  });

  test('maps the failures of the call', () async {
    final kinds = {
      sdkError(1): SamsungIapErrorKind.userCanceled,
      sdkError(-1002): SamsungIapErrorKind.general,
      sdkError(-1006): SamsungIapErrorKind.purchaseResultUnknown,
      sdkError(-1008): SamsungIapErrorKind.network,
      PlatformException(code: 'not_sent'): SamsungIapErrorKind.busy,
      PlatformException(code: 'result_unknown'):
          SamsungIapErrorKind.purchaseResultUnknown,
      PlatformException(code: 'store_unavailable'):
          SamsungIapErrorKind.storeUnavailable,
      PlatformException(code: 'not_initialized'):
          SamsungIapErrorKind.notInitialized,
    };
    for (final MapEntry(key: error, value: kind) in kinds.entries) {
      when(() => api.changeSubscriptionPlan(any(), any(), any(), any(), any()))
          .thenThrow(error);

      await expectLater(change(), throwsKind(kind), reason: '$error');
    }
  });

  test('reports the plan-change detail codes as general', () async {
    for (final detailCode in [1005, 1006, 1012, 1014]) {
      when(() => api.changeSubscriptionPlan(any(), any(), any(), any(), any()))
          .thenThrow(sdkError(-1002, details: 'IS$detailCode/6050/x'));

      await expectLater(
        change(),
        throwsA(
          isA<SamsungIapException>()
              .having((e) => e.kind, 'kind', SamsungIapErrorKind.general)
              .having((e) => e.code, 'code', -1002)
              .having((e) => e.detailCode, 'detailCode', detailCode),
        ),
        reason: '$detailCode',
      );
    }
  });
}
