import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:samsung_iap_flutter_platform_interface/src/enums.dart';
import 'package:samsung_iap_flutter_platform_interface/src/owned_product.dart';
import 'package:samsung_iap_flutter_platform_interface/src/product.dart';

export 'src/enums.dart';
export 'src/exception.dart';
export 'src/owned_product.dart';
export 'src/product.dart';

/// {@template samsung_iap_flutter_platform}
/// The interface that implementations of
/// samsung_iap_flutter must implement.
///
/// Platform implementations should extend this class
/// rather than implement it as `SamsungIapFlutter`.
///
/// Extending this class (using `extends`) ensures that the subclass will get
/// the default implementation, while platform implementations that `implements`
/// this interface will be broken by newly added
/// [SamsungIapFlutterPlatform] methods.
/// {@endtemplate}
abstract class SamsungIapFlutterPlatform extends PlatformInterface {
  /// {@macro samsung_iap_flutter_platform}
  new() : super(token: _token);

  static final Object _token = Object();

  static SamsungIapFlutterPlatform _instance = _PlaceholderImplementation();

  /// The default instance of [SamsungIapFlutterPlatform] to use.
  ///
  /// Until a platform implementation registers itself, every method throws
  /// [UnimplementedError].
  static SamsungIapFlutterPlatform get instance => _instance;

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [SamsungIapFlutterPlatform]
  /// when they register themselves.
  static set instance(SamsungIapFlutterPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Sets the operation mode and whether Samsung shows its own error dialogs.
  Future<void> initialize({
    required OperationMode mode,
    required bool showErrorDialog,
  }) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Reports whether Galaxy Store can serve purchases, without showing a
  /// dialog.
  Future<GalaxyStoreStatus> getGalaxyStoreStatus() {
    throw UnimplementedError(
      'getGalaxyStoreStatus() has not been implemented.',
    );
  }

  /// Fetches the products with [productIds], or every product when it is
  /// empty.
  Future<List<SamsungProduct>> getProducts(List<String> productIds) {
    throw UnimplementedError('getProducts() has not been implemented.');
  }

  /// Fetches the products the user owns that match [filter].
  Future<List<OwnedProduct>> getOwnedProducts(OwnedProductFilter filter) {
    throw UnimplementedError('getOwnedProducts() has not been implemented.');
  }
}

class _PlaceholderImplementation extends SamsungIapFlutterPlatform;
