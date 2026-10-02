/// What went wrong, grouped by what the app should do next.
///
/// Samsung reports a server error in one of two shapes. One is a -10xx code
/// with the server's detail code in [SamsungIapException.details]. The other
/// is the server's code itself with no details. Both shapes map to the same
/// kind, so -1007 with `IS9201/...` and a plain 9201 are both
/// [productNotFound].
///
/// Switch over it exhaustively so a new kind is a compile error, not a silent
/// fallthrough. If [SamsungIapException.dialogShown] is `true`, Samsung has
/// already shown the user an error, so do not show another.
enum SamsungIapErrorKind {
  /// The user closed the payment sheet. This is not a failure, so show
  /// nothing and do not log it as an error.
  userCanceled,

  /// The user already owns the product. Samsung reports -1003, or detail
  /// code 9224. Call `getOwnedProducts`, grant what it returns, and then
  /// consume or acknowledge it.
  alreadyOwned,

  /// The product ID does not exist in the current operation mode, or the app
  /// has no products, or IAP is not activated in Seller Portal.
  ///
  /// Samsung reports -1005 or -1007, or detail code 9201, 9202 or 9207. With
  /// 9201, the app has no registered products or IAP is not activated.
  ///
  /// This is a setup problem that the user cannot fix. Check the product ID,
  /// the operation mode, the Seller Portal settings and the distribution
  /// countries.
  productNotFound,

  /// The product or IAP itself is not sold in the user's country. Samsung
  /// reports -1012 or -1013, or detail code 9134 or 9259. Hide the store UI
  /// for this user.
  notAvailableInCountry,

  /// A network problem, or no answer from Samsung within 30 seconds.
  ///
  /// An inquiry, consume or acknowledge is safe to retry. A consume or
  /// acknowledge that went through reports `AckStatus.alreadyProcessed` on
  /// the retry. A purchase or plan change may have gone through, so reconcile
  /// owned products first, and retry only if the user does not own the
  /// product.
  network,

  /// Galaxy Store is missing, disabled or not genuine.
  ///
  /// [SamsungIapException.details] names the store status. Hide the store UI,
  /// or ask the user to install or enable Galaxy Store.
  storeUnavailable,

  /// The installed Galaxy Store is too old for this call. Send the user to
  /// Galaxy Store to update it, then retry.
  storeUpdateRequired,

  /// The user is not signed in to a Samsung account. Ask the user to sign
  /// in, then retry.
  ///
  /// The SDK 6.5.2 binary defines this code as -1014, and Samsung's docs list
  /// it as -1015. Both map here.
  accountNotSignedIn,

  /// Samsung could not confirm the outcome of a purchase or plan change, and
  /// the user may have paid. Reconcile owned products before telling the
  /// user anything.
  purchaseResultUnknown,

  /// Another Samsung IAP call was running, or Samsung is still finishing a
  /// call that timed out.
  ///
  /// Samsung refused the call before it showed any UI, so nothing was
  /// charged. Retry a few times with a growing delay. Samsung also refuses
  /// some invalid input this way, so stop retrying if `busy` persists, and
  /// log the call.
  busy,

  /// The plugin rejected an argument before calling Samsung. This is a bug
  /// in the app, so fix the call.
  invalidArgument,

  /// The call was made before `initialize`. This is a bug in the app, so
  /// call `initialize` first.
  notInitialized,

  /// Samsung IAP failed to initialize.
  ///
  /// Read [SamsungIapException.detailCode]. With 10011, Samsung's service
  /// failed to start, so retry a few times with a growing delay. With 10000,
  /// the IAP client app is invalid, and with 10001, the Samsung Checkout app
  /// is invalid. A retry does not fix those two, so hide the store UI.
  initializationFailed,

  /// Samsung's catch-all error. Samsung reports -1002, or a server code that
  /// no other kind claims. Switch on [SamsungIapException.detailCode]:
  ///
  /// - 100010: TEST mode, and the user is not a license tester.
  /// - 7002: Samsung blocked the purchase as a suspicious transaction.
  /// - 1005, 1006, 1012 and 1014: Samsung rejected a plan change. See
  ///   `changeSubscriptionPlan`.
  /// - 9226: `consume` got a missing or invalid purchase ID.
  /// - 9000, 9005, 9013 and 9014: `OperationMode.testFailure`, where every
  ///   call fails on purpose.
  ///
  /// Log other detail codes with [SamsungIapException.details].
  general,

  /// Samsung reported a negative code this plugin does not know, or the
  /// bridge reported an unknown error. Log [SamsungIapException.code] and
  /// [SamsungIapException.message].
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

  /// Samsung's response code as Samsung sent it, or `null` when the plugin
  /// raised the error. This is a -10xx code, 1 for a cancel, or a positive
  /// server code such as 9201.
  final int? code;

  /// Samsung's server detail code.
  ///
  /// For a -10xx [code], the digits before the first `/` of [details], for
  /// example `9224` from `IS9224/6050/NwCbCAxypi`. For a positive server
  /// [code] other than 1, the code itself, because Samsung sends no details
  /// with it.
  final int? detailCode;

  /// A human-readable description for logs. Not for end users.
  final String message;

  /// Samsung's raw error details string. For
  /// [SamsungIapErrorKind.storeUnavailable], the store status, for example
  /// `notInstalled`. For other plugin errors, diagnostic text for logs.
  final String? details;

  /// Whether Samsung already showed its own error dialog, so the app should
  /// not show another.
  final bool dialogShown;

  @override
  String toString() =>
      'SamsungIapException(${kind.name}, code: $code, '
      'detailCode: $detailCode, message: $message)';
}
