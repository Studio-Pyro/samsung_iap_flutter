import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samsung_iap_flutter_android/samsung_iap_flutter_android.dart';
import 'package:samsung_iap_flutter_android/src/messages.g.dart';
import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

import 'helpers.dart';

void main() {
  late MockHostApi api;
  late SamsungIapFlutterAndroid plugin;

  setUp(() => (api, plugin) = newPlugin());

  test('maps every status, without initialize', () async {
    final statuses = {
      PlatformStoreStatus.available: GalaxyStoreStatus.available,
      PlatformStoreStatus.notInstalled: GalaxyStoreStatus.notInstalled,
      PlatformStoreStatus.disabled: GalaxyStoreStatus.disabled,
      PlatformStoreStatus.invalid: GalaxyStoreStatus.invalid,
    };
    for (final MapEntry(key: wire, value: status) in statuses.entries) {
      when(api.getStoreStatus).thenAnswer((_) async => wire);

      expect(await plugin.getGalaxyStoreStatus(), status);
    }
    verifyNever(() => api.initialize(any(), any()));
  });

  test('answers while a getProducts call is still waiting', () async {
    final pending = Completer<List<PlatformProduct>>();
    when(() => api.getProductsDetails(any())).thenAnswer((_) => pending.future);
    when(api.getStoreStatus)
        .thenAnswer((_) async => PlatformStoreStatus.available);

    final products = plugin.getProducts([]);

    expect(await plugin.getGalaxyStoreStatus(), GalaxyStoreStatus.available);
    pending.complete([]);
    await products;
  });

  test('maps a bridge error', () async {
    when(api.getStoreStatus).thenThrow(PlatformException(code: 'boom'));

    await expectLater(plugin.getGalaxyStoreStatus(), throwsKind(.unknown));
  });
}
