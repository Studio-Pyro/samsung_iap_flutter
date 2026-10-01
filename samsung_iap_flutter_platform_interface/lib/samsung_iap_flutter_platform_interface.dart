import 'package:plugin_platform_interface/plugin_platform_interface.dart';

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

  /// Return the current platform name.
  Future<String?> getPlatformName() {
    throw UnimplementedError('getPlatformName() has not been implemented.');
  }
}

class _PlaceholderImplementation extends SamsungIapFlutterPlatform;
