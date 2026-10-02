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

  setUp(() async {
    (api, plugin) = newPlugin();
    await initializeForTest(plugin);
    when(() => api.getPromotionEligibility(any())).thenAnswer((_) async => []);
  });

  test('sends the subscription IDs comma-joined', () async {
    await plugin.getPromotionEligibility(['monthly']);
    await plugin.getPromotionEligibility(['monthly', 'yearly']);

    verify(() => api.getPromotionEligibility('monthly')).called(1);
    verify(() => api.getPromotionEligibility('monthly,yearly')).called(1);
  });

  test('maps each result, an unknown pricing included', () async {
    when(() => api.getPromotionEligibility(any())).thenAnswer(
      (_) async => [
        PlatformPromotionEligibility(
          itemId: 'monthly',
          pricing: 'FreeTrial',
          json: '{"itemID":"monthly"}',
        ),
        PlatformPromotionEligibility(
          itemId: 'yearly',
          pricing: 'TieredPrice',
          json: '{"itemID":"yearly"}',
        ),
        PlatformPromotionEligibility(
          itemId: 'weekly',
          pricing: 'LoyaltyPrice',
          json: '{"itemID":"weekly"}',
        ),
      ],
    );

    expect(
      await plugin.getPromotionEligibility(['monthly', 'yearly', 'weekly']),
      const [
        PromotionEligibility(
          productId: 'monthly',
          pricing: PromotionPricing.freeTrial,
          rawJson: '{"itemID":"monthly"}',
        ),
        PromotionEligibility(
          productId: 'yearly',
          pricing: PromotionPricing.tieredPrice,
          rawJson: '{"itemID":"yearly"}',
        ),
        PromotionEligibility(
          productId: 'weekly',
          pricing: PromotionPricing.unknown,
          rawJson: '{"itemID":"weekly"}',
        ),
      ],
    );
  });

  test('maps the failures of the call', () async {
    final kinds = {
      sdkError(-1008): SamsungIapErrorKind.network,
      sdkError(-1002): SamsungIapErrorKind.general,
      PlatformException(code: 'not_sent'): SamsungIapErrorKind.busy,
      PlatformException(code: 'timeout'): SamsungIapErrorKind.network,
      PlatformException(code: 'store_unavailable'):
          SamsungIapErrorKind.storeUnavailable,
      PlatformException(code: 'not_initialized'):
          SamsungIapErrorKind.notInitialized,
    };
    for (final MapEntry(key: error, value: kind) in kinds.entries) {
      when(() => api.getPromotionEligibility(any())).thenThrow(error);

      await expectLater(
        plugin.getPromotionEligibility(['monthly']),
        throwsKind(kind),
        reason: '$error',
      );
    }
  });
}
