import 'package:flutter/services.dart';
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

/// A batch where one purchase succeeds, one has an unknown ID, and one has a
/// status this plugin does not know.
final ackWires = [
  PlatformAckResult(purchaseId: 'a1b2c3', statusCode: 0, statusString: 'ok'),
  PlatformAckResult(purchaseId: 'bogus', statusCode: 1, statusString: 'no'),
  PlatformAckResult(purchaseId: 'd4e5f6', statusCode: 42, statusString: '?'),
];

/// [ackWires] as the public results.
const ackResults = [
  PurchaseAckResult(
    purchaseId: 'a1b2c3',
    status: AckStatus.success,
    statusCode: 0,
    message: 'ok',
  ),
  PurchaseAckResult(
    purchaseId: 'bogus',
    status: AckStatus.invalidPurchaseId,
    statusCode: 1,
    message: 'no',
  ),
  PurchaseAckResult(
    purchaseId: 'd4e5f6',
    status: AckStatus.unknown,
    statusCode: 42,
    message: '?',
  ),
];

/// A Samsung error for the whole call, as the Kotlin bridge sends it.
PlatformException sdkError(int code) => PlatformException(
  code: 'sdk',
  message: 'Samsung says no.',
  details: {'errorCode': code, 'errorDetails': '', 'dialogShown': false},
);

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
