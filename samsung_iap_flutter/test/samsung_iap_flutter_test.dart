import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:samsung_iap_flutter/samsung_iap_flutter.dart';
import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

class _MockPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements SamsungIapFlutterPlatform;

const _product = SamsungProduct(
  id: 'coins_100',
  name: '100 coins',
  description: '',
  type: SamsungProductType.item,
  price: 0.99,
  formattedPrice: '£0.99',
  currencyCode: 'GBP',
  currencySymbol: '£',
  subscriptionPeriod: null,
  freeTrialDays: null,
  introductoryOffer: null,
  availableFrom: null,
  availableUntil: null,
  imageUrl: null,
  downloadUrl: null,
  rawJson: '{}',
);

void main() {
  late _MockPlatform platform;
  const iap = SamsungIap();

  setUpAll(() => registerFallbackValue(OperationMode.production));

  setUp(() {
    platform = _MockPlatform();
    SamsungIapFlutterPlatform.instance = platform;
  });

  group('initialize', () {
    setUp(() {
      when(
        () => platform.initialize(
          mode: any(named: 'mode'),
          showErrorDialog: any(named: 'showErrorDialog'),
        ),
      ).thenAnswer((_) async {});
    });

    test('defaults to production with Samsung dialogs', () async {
      await iap.initialize();

      verify(
        () => platform.initialize(
          mode: OperationMode.production,
          showErrorDialog: true,
        ),
      ).called(1);
    });

    test('passes an explicit mode and dialog flag', () async {
      await iap.initialize(mode: OperationMode.test, showErrorDialog: false);

      verify(
        () => platform.initialize(
          mode: OperationMode.test,
          showErrorDialog: false,
        ),
      ).called(1);
    });
  });

  test('getGalaxyStoreStatus returns the platform status', () async {
    when(platform.getGalaxyStoreStatus)
        .thenAnswer((_) async => GalaxyStoreStatus.disabled);

    expect(await iap.getGalaxyStoreStatus(), GalaxyStoreStatus.disabled);
  });

  group('getProducts', () {
    setUp(() {
      when(() => platform.getProducts(any()))
          .thenAnswer((_) async => [_product]);
    });

    test('asks for every product by default', () async {
      expect(await iap.getProducts(), [_product]);

      verify(() => platform.getProducts([])).called(1);
    });

    test('passes the requested IDs', () async {
      await iap.getProducts(['coins_100', 'monthly']);

      verify(() => platform.getProducts(['coins_100', 'monthly'])).called(1);
    });

    test('rejects an empty or comma-joined ID before the platform', () async {
      for (final ids in [
        [''],
        ['coins_100', '  '],
        ['coins_100,monthly'],
      ]) {
        await expectLater(
          iap.getProducts(ids),
          throwsA(
            isA<SamsungIapException>().having(
              (e) => e.kind,
              'kind',
              SamsungIapErrorKind.invalidArgument,
            ),
          ),
          reason: '$ids',
        );
      }
      verifyNever(() => platform.getProducts(any()));
    });
  });
}
