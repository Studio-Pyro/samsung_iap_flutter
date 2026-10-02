import 'package:flutter/services.dart';
import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

const Map<int, SamsungIapErrorKind> _sdkKinds = {
  1: SamsungIapErrorKind.userCanceled,
  -1000: SamsungIapErrorKind.initializationFailed,
  -1001: SamsungIapErrorKind.storeUpdateRequired,
  -1002: SamsungIapErrorKind.general,
  -1003: SamsungIapErrorKind.alreadyOwned,
  -1005: SamsungIapErrorKind.productNotFound,
  -1006: SamsungIapErrorKind.purchaseResultUnknown,
  -1007: SamsungIapErrorKind.productNotFound,
  -1008: SamsungIapErrorKind.network,
  -1009: SamsungIapErrorKind.network,
  -1010: SamsungIapErrorKind.network,
  -1011: SamsungIapErrorKind.network,
  -1012: SamsungIapErrorKind.notAvailableInCountry,
  -1013: SamsungIapErrorKind.notAvailableInCountry,
  // The 6.5.2 binary defines -1014; Samsung's docs list -1015.
  -1014: SamsungIapErrorKind.accountNotSignedIn,
  -1015: SamsungIapErrorKind.accountNotSignedIn,
};

const Map<String, SamsungIapErrorKind> _pluginKinds = {
  'not_sent': SamsungIapErrorKind.busy,
  'not_initialized': SamsungIapErrorKind.notInitialized,
  'result_unknown': SamsungIapErrorKind.purchaseResultUnknown,
  'store_unavailable': SamsungIapErrorKind.storeUnavailable,
  'store_update_required': SamsungIapErrorKind.storeUpdateRequired,
  'timeout': SamsungIapErrorKind.network,
};

/// Converts an error from the Kotlin bridge into the public error type.
///
/// `sdk` errors carry `ErrorVo` as a map in [PlatformException.details].
/// Plugin errors carry a code from `_pluginKinds` and optional string details.
SamsungIapException exceptionFromPlatform(PlatformException e) {
  if ((e.code, e.details) case (
    'sdk',
    {
      'errorCode': final int code,
      'errorDetails': final String? details,
      'dialogShown': final bool dialogShown,
    },
  )) {
    return SamsungIapException(
      _sdkKinds[code] ?? SamsungIapErrorKind.unknown,
      message: e.message ?? '',
      code: code,
      detailCode: parseDetailCode(details),
      details: details,
      dialogShown: dialogShown,
    );
  }
  return SamsungIapException(
    _pluginKinds[e.code] ?? SamsungIapErrorKind.unknown,
    message: e.message ?? e.code,
    details: switch (e.details) {
      final String details => details,
      _ => null,
    },
  );
}

/// Parses the digits before the first `/` of Samsung's error details, for
/// example `9224` from `IS9224/6050/NwCbCAxypi`.
int? parseDetailCode(String? details) {
  final head = details?.split('/').first ?? '';
  final digits = RegExp(r'\d+').firstMatch(head)?[0];
  return digits == null ? null : int.parse(digits);
}
