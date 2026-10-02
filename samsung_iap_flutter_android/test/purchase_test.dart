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
  });

  void answerPayment(PlatformPurchase purchase) =>
      when(() => api.startPayment(any(), any(), any()))
          .thenAnswer((_) async => purchase);

  test('sends the product and obfuscated IDs', () async {
    answerPayment(purchaseWire());

    await plugin.purchase(
      'coins_100',
      obfuscatedAccountId: 'account',
      obfuscatedProfileId: 'profile',
    );
    await plugin.purchase('coins_500');

    verify(() => api.startPayment('coins_100', 'account', 'profile')).called(1);
    verify(() => api.startPayment('coins_500', null, null)).called(1);
  });

  test('maps a purchase with every field', () async {
    answerPayment(purchaseWire());

    expect(
      await plugin.purchase('coins_100'),
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

  test('maps a purchase whose optional fields Samsung left empty', () async {
    answerPayment(
      purchaseWire(
        itemPrice: double.nan,
        type: 'bundle',
        purchaseDate: '',
        minorStatus: '',
        obfuscatedAccountId: '',
        obfuscatedProfileId: '',
      ),
    );

    final purchase = await plugin.purchase('coins_100');

    expect(purchase.price, isNull);
    expect(purchase.type, SamsungProductType.unknown);
    expect(purchase.purchaseDate, isNull);
    expect(purchase.minorStatus, MinorStatus.unknown);
    expect(purchase.obfuscatedAccountId, isNull);
    expect(purchase.obfuscatedProfileId, isNull);
  });

  test('maps the purchase outcomes Samsung reports', () async {
    final kinds = {
      1: SamsungIapErrorKind.userCanceled,
      -1003: SamsungIapErrorKind.alreadyOwned,
      -1006: SamsungIapErrorKind.purchaseResultUnknown,
    };
    for (final MapEntry(key: code, value: kind) in kinds.entries) {
      when(() => api.startPayment(any(), any(), any())).thenThrow(
        PlatformException(
          code: 'sdk',
          message: 'Samsung says no.',
          details: {
            'errorCode': code,
            'errorDetails': '',
            'dialogShown': false,
          },
        ),
      );

      await expectLater(
        plugin.purchase('coins_100'),
        throwsKind(kind),
        reason: '$code',
      );
    }
  });

  test('maps the bridge errors of the call', () async {
    final kinds = {
      'not_sent': SamsungIapErrorKind.busy,
      'store_unavailable': SamsungIapErrorKind.storeUnavailable,
      'not_initialized': SamsungIapErrorKind.notInitialized,
    };
    for (final MapEntry(key: code, value: kind) in kinds.entries) {
      when(() => api.startPayment(any(), any(), any()))
          .thenThrow(PlatformException(code: code));

      await expectLater(
        plugin.purchase('coins_100'),
        throwsKind(kind),
        reason: code,
      );
    }
  });
}
