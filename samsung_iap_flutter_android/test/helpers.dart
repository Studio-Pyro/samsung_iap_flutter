import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samsung_iap_flutter_android/samsung_iap_flutter_android.dart';
import 'package:samsung_iap_flutter_android/src/messages.g.dart';
import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

class MockHostApi extends Mock implements SamsungIapHostApi;

/// A plugin over a fresh [MockHostApi] whose `initialize` succeeds.
(MockHostApi, SamsungIapFlutterAndroid) newPlugin() {
  registerFallbackValue(PlatformOperationMode.production);
  registerFallbackValue(PlatformOwnedProductFilter.all);
  final api = MockHostApi();
  when(() => api.initialize(any(), any())).thenAnswer((_) async {});
  return (api, SamsungIapFlutterAndroid(api: api));
}

Future<void> initializeForTest(SamsungIapFlutterAndroid plugin) =>
    plugin.initialize(mode: OperationMode.test, showErrorDialog: true);

Matcher throwsKind(SamsungIapErrorKind kind) =>
    throwsA(isA<SamsungIapException>().having((e) => e.kind, 'kind', kind));

/// A `PurchaseVo` mirror with every field set.
PlatformPurchase purchaseWire({
  double? itemPrice = 0.99,
  String type = 'item',
  String purchaseDate = '2026-01-01 09:00:00',
  String minorStatus = 'NOT_MINOR',
  String obfuscatedAccountId = 'account',
  String obfuscatedProfileId = 'profile',
}) => PlatformPurchase(
  itemId: 'coins_100',
  itemName: '100 coins',
  itemPrice: itemPrice,
  itemPriceString: '£0.99',
  currencyCode: 'GBP',
  type: type,
  paymentId: 'TPMTID20260101',
  purchaseId: 'a1b2c3',
  orderId: 'S20260101KRA1234567',
  purchaseDate: purchaseDate,
  minorStatus: minorStatus,
  obfuscatedAccountId: obfuscatedAccountId,
  obfuscatedProfileId: obfuscatedProfileId,
  json: '{"mPurchaseId":"a1b2c3"}',
);
