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
    for (final id in productIds) {
      if (id.trim().isEmpty || id.contains(',')) {
        throw SamsungIapException(
          SamsungIapErrorKind.invalidArgument,
          message: 'Invalid product ID: "$id".',
        );
      }
    }
    return await _platform.getProducts(productIds);
  }

  /// Fetches the products the user owns, filtered to items, subscriptions or
  /// [OwnedProductFilter.all].
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
}
