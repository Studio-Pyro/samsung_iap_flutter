import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samsung_iap_flutter_android/samsung_iap_flutter_android.dart';
import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

import 'helpers.dart';

void main() {
  late MockHostApi api;
  late SamsungIapFlutterAndroid plugin;

  setUp(() async {
    (api, plugin) = newPlugin();
    await initializeForTest(plugin);
  });

  Future<SamsungIapException> failWith(PlatformException error) async {
    when(() => api.getProductsDetails(any())).thenThrow(error);
    try {
      await plugin.getProducts([]);
    } on SamsungIapException catch (e) {
      return e;
    }
    fail('getProducts did not throw');
  }

  test(
    'maps every Samsung response code to its kind and keeps dialogShown',
    () async {
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
        for (final dialogShown in [true, false]) {
          final e = await failWith(sdkError(code, dialogShown: dialogShown));

          expect(e.kind, kind, reason: '$code');
          expect(e.code, code);
          expect(e.dialogShown, dialogShown, reason: '$code');
        }
      }
    },
  );

  test('keeps the raw Samsung fields', () async {
    final e = await failWith(
      sdkError(-1003, details: 'IS9224/6050/x', dialogShown: true),
    );

    expect(e.message, 'Samsung says no.');
    expect(e.details, 'IS9224/6050/x');
    expect(e.detailCode, 9224);
    expect(e.dialogShown, isTrue);
  });

  test('parses the detail code before the first slash', () async {
    final detailCodes = <String?, int?>{
      'IS9224/6050/NwCbCAxypi': 9224,
      '9226/6050/x': 9226,
      'E7002/x': 7002,
      'IS9013': 9013,
      '100010': 100010,
      '1014 change requested/x': 1014,
      'IS9224 then 6050/x': 9224,
      'abc/123': null,
      '/9224/6050': null,
      'IS/9224': null,
      'Unknown error': null,
      '99999999999999999999/x': null,
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
      'result_unknown': SamsungIapErrorKind.purchaseResultUnknown,
      'IllegalStateException': SamsungIapErrorKind.unknown,
    };
    for (final MapEntry(key: code, value: kind) in kinds.entries) {
      final e = await failWith(PlatformException(code: code));

      expect(e.kind, kind, reason: code);
      expect(e.message, code);
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
}
