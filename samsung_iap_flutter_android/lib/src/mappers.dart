import 'package:samsung_iap_flutter_android/src/messages.g.dart';
import 'package:samsung_iap_flutter_platform_interface/parsing.dart';
import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

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
    price: double.tryParse(p.tieredPrice),
    formattedPrice: p.tieredPriceString,
    period: period,
    cycles: cycles,
  );
}
