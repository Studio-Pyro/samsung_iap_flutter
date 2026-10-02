import 'dart:convert';

import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

export 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart'
    hide SamsungIapFlutterPlatform;

/// Samsung In-App Purchase on Galaxy Store.
///
/// Every method throws [SamsungIapException] on failure. Create it with
/// `const SamsungIap()`, or replace it with a mock in tests.
class SamsungIap {
  /// Creates the client. It holds no state.
  const new();

  SamsungIapFlutterPlatform get _platform => SamsungIapFlutterPlatform.instance;

  /// Configures Samsung IAP. Call it once before any method other than
  /// [getGalaxyStoreStatus].
  ///
  /// [mode] defaults to [OperationMode.production], so a forgotten setting
  /// never ships a test build. With [showErrorDialog] `true`, Samsung shows
  /// its own error dialogs and [SamsungIapException.dialogShown] reports it.
  Future<void> initialize({
    OperationMode mode = OperationMode.production,
    bool showErrorDialog = true,
  }) => _platform.initialize(mode: mode, showErrorDialog: showErrorDialog);

  /// Reports whether Galaxy Store can serve purchases. Shows no dialog and
  /// works before [initialize].
  Future<GalaxyStoreStatus> getGalaxyStoreStatus() =>
      _platform.getGalaxyStoreStatus();

  /// Fetches the products with [productIds], or every product when it is
  /// empty. The order of the result is not guaranteed.
  ///
  /// Throws a [SamsungIapException] of kind
  /// [SamsungIapErrorKind.invalidArgument] for an empty ID or one that
  /// contains a comma, [SamsungIapErrorKind.storeUnavailable] when Galaxy
  /// Store is not usable, and [SamsungIapErrorKind.network] when Samsung does
  /// not answer within 30 seconds.
  Future<List<SamsungProduct>> getProducts([
    List<String> productIds = const [],
  ]) async {
    _checkIds('product', productIds);
    return await _platform.getProducts(productIds);
  }

  /// Fetches the products the user owns. [filter] picks items, subscriptions
  /// or both.
  ///
  /// Call it at every app launch and grant what it returns, so a purchase
  /// interrupted by process death is never lost. The dates on each
  /// [OwnedProduct] are device-local and approximate. Verify entitlement
  /// windows against Samsung's server receipt.
  ///
  /// Throws a [SamsungIapException] of kind
  /// [SamsungIapErrorKind.storeUnavailable] when Galaxy Store is not usable,
  /// and [SamsungIapErrorKind.network] when Samsung does not answer within 30
  /// seconds.
  Future<List<OwnedProduct>> getOwnedProducts({
    OwnedProductFilter filter = OwnedProductFilter.all,
  }) => _platform.getOwnedProducts(filter);

  /// Shows Samsung's payment sheet for [productId] and returns the purchase.
  ///
  /// There is no timeout, so the user can take as long as they need. Pass
  /// [obfuscatedAccountId], and optionally [obfuscatedProfileId], to let your
  /// server match the purchase to a user. Each must be a hash of your own
  /// IDs, at most 64 bytes in UTF-8 and not an email address. A profile ID
  /// needs an account ID.
  ///
  /// Throws a [SamsungIapException]. Its kind tells the app what to do:
  ///
  /// - [SamsungIapErrorKind.userCanceled]: the user closed the sheet. Not an
  ///   error, so show nothing.
  /// - [SamsungIapErrorKind.alreadyOwned],
  ///   [SamsungIapErrorKind.purchaseResultUnknown] and
  ///   [SamsungIapErrorKind.network]: the user may own the product. Call
  ///   [getOwnedProducts] and grant what it returns before telling the user
  ///   anything. After `network`, retry only if the product is not owned.
  /// - [SamsungIapErrorKind.busy]: Samsung refused to start, so nothing was
  ///   charged. Retry after a short wait.
  /// - [SamsungIapErrorKind.invalidArgument]: an empty product ID, or an
  ///   obfuscated ID that breaks the rules above. Nothing is sent to Samsung.
  Future<SamsungPurchase> purchase(
    String productId, {
    String? obfuscatedAccountId,
    String? obfuscatedProfileId,
  }) async {
    if (productId.trim().isEmpty) {
      throw const SamsungIapException(
        SamsungIapErrorKind.invalidArgument,
        message: 'The product ID is empty.',
      );
    }
    _checkObfuscatedIds(obfuscatedAccountId, obfuscatedProfileId);
    return await _platform.purchase(
      productId,
      obfuscatedAccountId: obfuscatedAccountId,
      obfuscatedProfileId: obfuscatedProfileId,
    );
  }

  /// Consumes the purchases with [purchaseIds], so the user can buy those
  /// items again. Use it for repeatable items such as coins, after you have
  /// granted them.
  ///
  /// Returns one [PurchaseAckResult] per purchase. A batch can partly fail,
  /// so check each result. [PurchaseAckResult.isProcessed] is `true` for a
  /// purchase that is done, including one that an earlier call handled.
  ///
  /// Throws a [SamsungIapException] when the call as a whole fails: of kind
  /// [SamsungIapErrorKind.invalidArgument] for an empty list, an empty ID or
  /// one that contains a comma, [SamsungIapErrorKind.storeUnavailable] when
  /// Galaxy Store is not usable, and [SamsungIapErrorKind.network] when
  /// Samsung does not answer within 30 seconds. Unlike a failed [purchase],
  /// a [SamsungIapErrorKind.network] failure here is safe to retry as is:
  /// Samsung may still apply a call that timed out, and the retry then
  /// reports [AckStatus.alreadyProcessed].
  Future<List<PurchaseAckResult>> consume(List<String> purchaseIds) async {
    _checkPurchaseIds(purchaseIds);
    return await _platform.consume(purchaseIds);
  }

  /// Acknowledges the purchases with [purchaseIds] without consuming them.
  /// Use it for permanent unlocks and subscriptions, after you have granted
  /// them.
  ///
  /// Returns one [PurchaseAckResult] per purchase, and throws, like
  /// [consume]. It also throws a [SamsungIapException] of kind
  /// [SamsungIapErrorKind.storeUpdateRequired] when Galaxy Store is older
  /// than 4.5.90, which cannot acknowledge.
  Future<List<PurchaseAckResult>> acknowledge(List<String> purchaseIds) async {
    _checkPurchaseIds(purchaseIds);
    return await _platform.acknowledge(purchaseIds);
  }
}

/// Rejects an ID that Samsung's comma-joined lists cannot carry.
void _checkIds(String kind, List<String> ids) {
  for (final id in ids) {
    if (id.trim().isEmpty || id.contains(',')) {
      throw SamsungIapException(
        SamsungIapErrorKind.invalidArgument,
        message: 'Invalid $kind ID: "$id".',
      );
    }
  }
}

void _checkPurchaseIds(List<String> ids) {
  if (ids.isEmpty) {
    throw const SamsungIapException(
      SamsungIapErrorKind.invalidArgument,
      message: 'The list of purchase IDs is empty.',
    );
  }
  _checkIds('purchase', ids);
}

// The same pattern the SDK refuses with, so the app gets invalidArgument
// instead of the SDK's silent refusal, which surfaces as busy.
final _email = RegExp(
  r'^[_A-Za-z0-9-]+(\.[_A-Za-z0-9-]+)*@[A-Za-z0-9]+(\.[A-Za-z0-9]+)*'
  r'(\.[A-Za-z]{2,})$',
);

void _checkObfuscatedIds(String? accountId, String? profileId) {
  if (profileId != null && accountId == null) {
    throw const SamsungIapException(
      SamsungIapErrorKind.invalidArgument,
      message: 'An obfuscated profile ID needs an obfuscated account ID.',
    );
  }
  for (final (name, id) in [('account', accountId), ('profile', profileId)]) {
    if (id == null) continue;
    final problem = switch (id) {
      '' => 'is empty; pass null to omit it',
      _ when utf8.encode(id).length > 64 => 'is longer than 64 UTF-8 bytes',
      _ when _email.hasMatch(id) => 'looks like an email address',
      _ => null,
    };
    if (problem != null) {
      throw SamsungIapException(
        SamsungIapErrorKind.invalidArgument,
        message: 'The obfuscated $name ID $problem.',
      );
    }
  }
}
