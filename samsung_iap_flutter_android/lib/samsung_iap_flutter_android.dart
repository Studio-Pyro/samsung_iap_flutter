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

  /// How long an inquiry waits for Samsung before failing.
  @visibleForTesting
  static const inquiryTimeout = Duration(seconds: 30);

  final SamsungIapHostApi _api;
  Future<void> _queue = Future.value();
  bool _initialized = false;

  /// Registers this class as the default instance of
  /// [SamsungIapFlutterPlatform].
  static void registerWith() {
    SamsungIapFlutterPlatform.instance = SamsungIapFlutterAndroid();
  }

  @override
  Future<void> initialize({
    required OperationMode mode,
    required bool showErrorDialog,
  }) => _enqueue(() async {
    await _api.initialize(switch (mode) {
      OperationMode.production => PlatformOperationMode.production,
      OperationMode.test => PlatformOperationMode.test,
      OperationMode.testFailure => PlatformOperationMode.testFailure,
    }, showErrorDialog);
    _initialized = true;
  });

  @override
  Future<GalaxyStoreStatus> getGalaxyStoreStatus() => _enqueue(() async {
    _requireInitialized();
    return switch (await _api.getStoreStatus()) {
      PlatformStoreStatus.available => GalaxyStoreStatus.available,
      PlatformStoreStatus.notInstalled => GalaxyStoreStatus.notInstalled,
      PlatformStoreStatus.disabled => GalaxyStoreStatus.disabled,
      PlatformStoreStatus.invalid => GalaxyStoreStatus.invalid,
    };
  });

  @override
  Future<List<SamsungProduct>> getProducts(List<String> productIds) =>
      _enqueue(() async {
        _requireInitialized();
        final products = await _api
            .getProductsDetails(productIds.join(','))
            .timeout(inquiryTimeout, onTimeout: () => _timedOut('getProducts'));
        return products.map(productFromPlatform).toList();
      });

  /// Runs [call] after every earlier call has settled, so a failure never
  /// blocks the calls behind it.
  Future<T> _enqueue<T>(Future<T> Function() call) {
    final result = _queue.then((_) async {
      try {
        return await call();
      } on PlatformException catch (e) {
        throw exceptionFromPlatform(e);
      }
    });
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  void _requireInitialized() {
    if (!_initialized) {
      throw const SamsungIapException(
        SamsungIapErrorKind.notInitialized,
        message: 'Call initialize before any other Samsung IAP call.',
      );
    }
  }

  static Never _timedOut(String method) => throw SamsungIapException(
    SamsungIapErrorKind.unknown,
    message:
        '$method got no answer from Samsung within '
        '${inquiryTimeout.inSeconds}s.',
  );
}
