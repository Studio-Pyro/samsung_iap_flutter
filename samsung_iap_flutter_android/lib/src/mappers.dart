import 'package:samsung_iap_flutter_android/src/messages.g.dart';
import 'package:samsung_iap_flutter_android/src/parsing.dart';
import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

/// Converts the public operation mode into its wire form.
PlatformOperationMode operationModeToPlatform(OperationMode mode) =>
    switch (mode) {
      OperationMode.production => PlatformOperationMode.production,
      OperationMode.test => PlatformOperationMode.test,
      OperationMode.testFailure => PlatformOperationMode.testFailure,
    };

/// Converts the wire store status into the public one.
GalaxyStoreStatus storeStatusFromPlatform(PlatformStoreStatus status) =>
    switch (status) {
      PlatformStoreStatus.available => GalaxyStoreStatus.available,
      PlatformStoreStatus.notInstalled => GalaxyStoreStatus.notInstalled,
      PlatformStoreStatus.disabled => GalaxyStoreStatus.disabled,
      PlatformStoreStatus.invalid => GalaxyStoreStatus.invalid,
    };

/// Converts the public owned-product filter into its wire form.
PlatformOwnedProductFilter ownedProductFilterToPlatform(
  OwnedProductFilter filter,
) => switch (filter) {
  OwnedProductFilter.item => PlatformOwnedProductFilter.item,
  OwnedProductFilter.subscription => PlatformOwnedProductFilter.subscription,
  OwnedProductFilter.all => PlatformOwnedProductFilter.all,
};

/// Converts the wire mirror of `OwnedProductVo` into the public model.
OwnedProduct ownedProductFromPlatform(PlatformOwnedProduct p) => OwnedProduct(
  productId: p.itemId,
  name: p.itemName,
  purchaseId: p.purchaseId,
  paymentId: p.paymentId,
  type: parseProductType(p.type),
  purchaseDate: parseLocalDateTime(p.purchaseDate),
  subscriptionEndDate: parseLocalDateTime(p.subscriptionEndDate),
  acknowledgedStatus: parseAcknowledgedStatus(p.acknowledgedStatus),
  priceChange: _priceChange(p.subscriptionPriceChange),
  obfuscatedAccountId: nonEmptyOrNull(p.obfuscatedAccountId),
  obfuscatedProfileId: nonEmptyOrNull(p.obfuscatedProfileId),
  price: finiteOrNull(p.itemPrice),
  formattedPrice: p.itemPriceString,
  currencyCode: p.currencyCode,
  rawJson: p.json,
);

/// Converts the wire mirror of `PurchaseVo` into the public model.
SamsungPurchase purchaseFromPlatform(PlatformPurchase p) => SamsungPurchase(
  productId: p.itemId,
  name: p.itemName,
  purchaseId: p.purchaseId,
  paymentId: p.paymentId,
  orderId: p.orderId,
  type: parseProductType(p.type),
  purchaseDate: parseLocalDateTime(p.purchaseDate),
  minorStatus: parseMinorStatus(p.minorStatus),
  obfuscatedAccountId: nonEmptyOrNull(p.obfuscatedAccountId),
  obfuscatedProfileId: nonEmptyOrNull(p.obfuscatedProfileId),
  price: finiteOrNull(p.itemPrice),
  formattedPrice: p.itemPriceString,
  currencyCode: p.currencyCode,
  rawJson: p.json,
);

/// Converts the wire mirror of `ConsumeVo` or `AcknowledgeVo` into the public
/// model.
PurchaseAckResult ackResultFromPlatform(PlatformAckResult r) =>
    PurchaseAckResult(
      purchaseId: r.purchaseId,
      status: parseAckStatus(r.statusCode),
      statusCode: r.statusCode,
      message: r.statusString,
    );

SubscriptionPriceChange? _priceChange(PlatformSubscriptionPriceChange? c) =>
    c == null
    ? null
    : SubscriptionPriceChange(
        mode: parsePriceChangeMode(c.priceChangeMode),
        consented: c.isConsented,
        startDate: parseLocalDateTime(c.startDate),
        originalPrice: finiteOrNull(c.originalLocalPrice),
        originalFormattedPrice: c.originalLocalPriceString,
        newPrice: finiteOrNull(c.newLocalPrice),
        newFormattedPrice: c.newLocalPriceString,
        period: parseSubscriptionPeriod(
          multiplier: c.subscriptionDurationMultiplier,
          unit: c.subscriptionDurationUnit,
        ),
      );

/// Converts the wire mirror of `ProductVo` into the public model.
SamsungProduct productFromPlatform(PlatformProduct p) => SamsungProduct(
  id: p.itemId,
  name: p.itemName,
  description: p.itemDesc,
  type: parseProductType(p.type),
  price: finiteOrNull(p.itemPrice),
  formattedPrice: p.itemPriceString,
  currencyCode: p.currencyCode,
  currencySymbol: p.currencyUnit,
  subscriptionPeriod: parseSubscriptionPeriod(
    multiplier: p.subscriptionDurationMultiplier,
    unit: p.subscriptionDurationUnit,
  ),
  freeTrialDays: int.tryParse(p.freeTrialPeriod),
  introductoryOffer: _introductoryOffer(p),
  availableFrom: parseLocalDateTime(p.showStartDate),
  availableUntil: parseLocalDateTime(p.showEndDate),
  imageUrl: parseUri(p.itemImageUrl),
  downloadUrl: parseUri(p.itemDownloadUrl),
  rawJson: p.json,
);

IntroductoryOffer? _introductoryOffer(PlatformProduct p) {
  if (parseYesNo(p.tieredSubscriptionYN) != true) return null;
  final period = parseSubscriptionPeriod(
    multiplier: p.tieredSubscriptionDurationMultiplier,
    unit: p.tieredSubscriptionDurationUnit,
  );
  final cycles = int.tryParse(p.tieredSubscriptionCount);
  if (period == null || cycles == null) return null;
  return IntroductoryOffer(
    price: finiteOrNull(double.tryParse(p.tieredPrice)),
    formattedPrice: p.tieredPriceString,
    period: period,
    cycles: cycles,
  );
}
