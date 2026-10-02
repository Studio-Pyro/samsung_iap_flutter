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

  test('maps both shapes of a Samsung server error to one model', () async {
    // The service path passes Galaxy Store's raw server code and no details.
    // The payment path passes a -10xx code with the server code in details.
    // The first five rows are what a Galaxy S22 with Galaxy Store 4.6.11.4
    // returned in TEST and TEST_FAILURE modes.
    final rows = <(int, String?), (SamsungIapErrorKind, int?)>{
      (9201, ''): (SamsungIapErrorKind.productNotFound, 9201),
      (9005, ''): (SamsungIapErrorKind.general, 9005),
      (9000, ''): (SamsungIapErrorKind.general, 9000),
      (9207, ''): (SamsungIapErrorKind.productNotFound, 9207),
      (-1005, 'IS9207/6050/x'): (SamsungIapErrorKind.productNotFound, 9207),
      (-1002, 'IS9201/9001/RLgulQFMNH'): (
        SamsungIapErrorKind.productNotFound,
        9201,
      ),
      (-1007, 'IS9201/9001/x'): (SamsungIapErrorKind.productNotFound, 9201),
      (9202, null): (SamsungIapErrorKind.productNotFound, 9202),
      (9224, ''): (SamsungIapErrorKind.alreadyOwned, 9224),
      (-1002, 'IS9224/6050/x'): (SamsungIapErrorKind.alreadyOwned, 9224),
      (9134, ''): (SamsungIapErrorKind.notAvailableInCountry, 9134),
      (9259, ''): (SamsungIapErrorKind.notAvailableInCountry, 9259),
      (-1002, 'IS9259/x'): (SamsungIapErrorKind.notAvailableInCountry, 9259),
      (100010, ''): (SamsungIapErrorKind.general, 100010),
      (7002, 'IS1/x'): (SamsungIapErrorKind.general, 7002),
      (2, ''): (SamsungIapErrorKind.general, 2),
      (-1002, 'IS9000/9004/hqaYhProtq'): (SamsungIapErrorKind.general, 9000),
      (-1005, 'IS9224/x'): (SamsungIapErrorKind.productNotFound, 9224),
      (1, 'IS9201/x'): (SamsungIapErrorKind.userCanceled, 9201),
      (1, ''): (SamsungIapErrorKind.userCanceled, null),
      (-9999, 'IS9201/x'): (SamsungIapErrorKind.unknown, 9201),
    };
    for (final MapEntry(key: (code, details), value: (kind, detailCode))
        in rows.entries) {
      final e = await failWith(sdkError(code, details: details));
      final reason = '$code $details';

      expect(e.kind, kind, reason: reason);
      expect(e.code, code, reason: reason);
      expect(e.detailCode, detailCode, reason: reason);
      expect(e.details, details, reason: reason);
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
