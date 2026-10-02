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

/// Samsung's server detail codes that name a specific kind. Samsung documents
/// each under the -10xx code of that kind.
const Map<int, SamsungIapErrorKind> _detailKinds = {
  9201: SamsungIapErrorKind.productNotFound,
  9202: SamsungIapErrorKind.productNotFound,
  9207: SamsungIapErrorKind.productNotFound,
  9224: SamsungIapErrorKind.alreadyOwned,
  9134: SamsungIapErrorKind.notAvailableInCountry,
  9259: SamsungIapErrorKind.notAvailableInCountry,
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
///
/// `ErrorVo` comes in two shapes. The payment screens return a -10xx code
/// with the server code in the details, such as -1005 and `IS9207/...`.
/// The service calls return the raw server code, such as 9201, and no
/// details. Both become the same kind and [SamsungIapException.detailCode].
SamsungIapException exceptionFromPlatform(PlatformException e) {
  if ((e.code, e.details) case (
    'sdk',
    {
      'errorCode': final int code,
      'errorDetails': final String? details,
      'dialogShown': final bool dialogShown,
    },
  )) {
    // The SDK's own codes are 0, 1 (canceled) and -10xx.
    final isServerCode = code > 1;
    final detailCode = isServerCode ? code : parseDetailCode(details);
    final kind = isServerCode
        ? SamsungIapErrorKind.general
        : _sdkKinds[code] ?? SamsungIapErrorKind.unknown;
    return SamsungIapException(
      kind == SamsungIapErrorKind.general
          ? _detailKinds[detailCode] ?? kind
          : kind,
      message: e.message ?? '',
      code: code,
      detailCode: detailCode,
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
/// example `9224` from `IS9224/6050/NwCbCAxypi`. Returns `null` instead of
/// throwing when there are none or they overflow an `int`.
int? parseDetailCode(String? details) {
  final head = details?.split('/').first ?? '';
  return int.tryParse(RegExp(r'\d+').firstMatch(head)?[0] ?? '');
}
