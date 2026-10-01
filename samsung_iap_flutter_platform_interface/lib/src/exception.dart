/// What went wrong, grouped by what the app should do next.
///
/// Switch over it exhaustively so a new kind is a compile error, not a silent
/// fallthrough.
enum SamsungIapErrorKind {
  /// The user closed the payment sheet. Not a failure.
  userCanceled,

  /// The user already owns the product. Reconcile owned products and grant
  /// access.
  alreadyOwned,

  /// The product ID does not exist in the current operation mode, or IAP is
  /// not activated in Seller Portal.
  productNotFound,

  /// The product or IAP itself is not sold in the user's country.
  notAvailableInCountry,

  /// A network problem. Safe to retry.
  network,

  /// Galaxy Store is missing, disabled or not genuine.
  storeUnavailable,

  /// The installed Galaxy Store is too old for this call.
  storeUpdateRequired,

  /// The user is not signed in to a Samsung account.
  accountNotSignedIn,

  /// Samsung could not confirm the outcome of a purchase. Reconcile owned
  /// products before telling the user anything.
  purchaseResultUnknown,

  /// Another Samsung IAP call was running.
  busy,

  /// The plugin rejected an argument before calling Samsung.
  invalidArgument,

  /// The call was made before `initialize`.
  notInitialized,

  /// Samsung IAP failed to initialize. Safe to retry.
  initializationFailed,

  /// Samsung's catch-all error. See [SamsungIapException.detailCode].
  general,

  /// Anything else, including a call Samsung never answered. See
  /// [SamsungIapException.code] and [SamsungIapException.message].
  unknown,
}

/// The single error type every Samsung IAP call throws.
final class SamsungIapException implements Exception {
  /// Creates an exception of [kind].
  const new(
    this.kind, {
    required this.message,
    this.code,
    this.detailCode,
    this.details,
    this.dialogShown = false,
  });

  /// What went wrong.
  final SamsungIapErrorKind kind;

  /// Samsung's response code, or `null` when the plugin raised the error.
  final int? code;

  /// The detail code parsed from [details], for example `9224` from
  /// `IS9224/6050/NwCbCAxypi`.
  final int? detailCode;

  /// A human-readable description for logs. Not for end users.
  final String message;

  /// Samsung's raw error details string.
  final String? details;

  /// Whether Samsung already showed its own error dialog, so the app should
  /// not show another.
  final bool dialogShown;

  @override
  String toString() =>
      'SamsungIapException(${kind.name}, code: $code, '
      'detailCode: $detailCode, message: $message)';
}
