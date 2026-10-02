import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:samsung_iap_flutter_android/src/errors.dart';
import 'package:samsung_iap_flutter_android/src/mappers.dart';
import 'package:samsung_iap_flutter_android/src/messages.g.dart';
import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

/// {@template samsung_iap_flutter_android}
/// The Android implementation of [SamsungIapFlutterPlatform].
///
/// Runs one SDK call at a time, because Samsung refuses a payment while any
/// other call is running.
/// {@endtemplate}
class SamsungIapFlutterAndroid extends SamsungIapFlutterPlatform {
  /// {@macro samsung_iap_flutter_android}
  new({@visibleForTesting SamsungIapHostApi? api})
    : _api = api ?? SamsungIapHostApi();

  final SamsungIapHostApi _api;
  Future<void> _queue = Future.value();

  /// Registers this class as the default instance of
  /// [SamsungIapFlutterPlatform].
  static void registerWith() {
    SamsungIapFlutterPlatform.instance = SamsungIapFlutterAndroid();
  }

  @override
  Future<void> initialize({
    required OperationMode mode,
    required bool showErrorDialog,
  }) => _enqueue(
    () => _api.initialize(operationModeToPlatform(mode), showErrorDialog),
  );

  @override
  Future<GalaxyStoreStatus> getGalaxyStoreStatus() => _mapErrors(
    () async => storeStatusFromPlatform(await _api.getStoreStatus()),
  );

  @override
  Future<List<SamsungProduct>> getProducts(List<String> productIds) =>
      _enqueue(() async {
        final products = await _api.getProductsDetails(productIds.join(','));
        return products.map(productFromPlatform).toList();
      });

  @override
  Future<List<OwnedProduct>> getOwnedProducts(OwnedProductFilter filter) =>
      _enqueue(() async {
        final owned = await _api.getOwnedList(
          ownedProductFilterToPlatform(filter),
        );
        return owned.map(ownedProductFromPlatform).toList();
      });

  /// Runs [call] after every earlier call has settled, so a failure never
  /// blocks the calls behind it.
  Future<T> _enqueue<T>(Future<T> Function() call) {
    final result = _queue.then((_) => _mapErrors(call));
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  static Future<T> _mapErrors<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (e) {
      throw exceptionFromPlatform(e);
    }
  }
}
