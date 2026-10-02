import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

/// Returns `null` for the NaN the SDK sends for a missing price.
double? finiteOrNull(double? value) =>
    value == null || !value.isFinite ? null : value;

/// Parses Samsung's `Y`/`N` flags. Anything else is `null`.
bool? parseYesNo(String value) => switch (value) {
  'Y' => true,
  'N' => false,
  _ => null,
};

final _localDateTime = RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$');

/// Parses the SDK's `yyyy-MM-dd HH:mm:ss` strings as device-local time.
///
/// The SDK formats a missing timestamp as the Unix epoch, so that becomes
/// `null` too.
DateTime? parseLocalDateTime(String value) {
  if (!_localDateTime.hasMatch(value)) return null;
  final parsed = DateTime.parse(value);
  return parsed.millisecondsSinceEpoch == 0 ? null : parsed;
}

/// Returns `null` for the empty string the SDK sends for a missing value.
String? nonEmptyOrNull(String value) => value.isEmpty ? null : value;

/// Parses a URL, or returns `null` for an empty or malformed one.
Uri? parseUri(String value) => value.isEmpty ? null : Uri.tryParse(value);

/// Parses the name of the SDK's `AcknowledgedStatus` constant.
AcknowledgedStatus parseAcknowledgedStatus(String value) => switch (value) {
  'UNSUPPORTED' => AcknowledgedStatus.unsupported,
  'NOT_ACKNOWLEDGED' => AcknowledgedStatus.notAcknowledged,
  'ACKNOWLEDGED' => AcknowledgedStatus.acknowledged,
  _ => AcknowledgedStatus.unknown,
};

/// Parses the name of the SDK's `MinorStatus` constant.
MinorStatus parseMinorStatus(String value) => switch (value) {
  'UNIDENTIFIED' => MinorStatus.unidentified,
  'NOT_MINOR' => MinorStatus.notMinor,
  'MINOR' => MinorStatus.minor,
  _ => MinorStatus.unknown,
};

/// Parses the name of the SDK's `PriceChangeMode` constant.
PriceChangeMode parsePriceChangeMode(String value) => switch (value) {
  'PRICE_INCREASE_USER_AGREEMENT_REQUIRED' =>
    PriceChangeMode.increaseConsentRequired,
  'PRICE_INCREASE_NO_USER_AGREEMENT_REQUIRED' =>
    PriceChangeMode.increaseNoConsentRequired,
  'PRICE_DECREASE' => PriceChangeMode.decrease,
  _ => PriceChangeMode.unknown,
};

/// Parses the status code of a `ConsumeVo` or `AcknowledgeVo`.
AckStatus parseAckStatus(int code) => switch (code) {
  0 => AckStatus.success,
  1 => AckStatus.invalidPurchaseId,
  2 => AckStatus.failedOrder,
  3 => AckStatus.invalidProductType,
  4 => AckStatus.alreadyProcessed,
  5 => AckStatus.unauthorized,
  9 => AckStatus.serviceError,
  _ => AckStatus.unknown,
};

/// Parses the SDK's `item`/`subscription` product type.
SamsungProductType parseProductType(String value) => switch (value) {
  'item' => SamsungProductType.item,
  'subscription' => SamsungProductType.subscription,
  _ => SamsungProductType.unknown,
};

/// Parses the SDK's `WEEK`/`MONTH`/`YEAR` duration unit.
PeriodUnit parsePeriodUnit(String value) => switch (value) {
  'WEEK' => PeriodUnit.week,
  'MONTH' => PeriodUnit.month,
  'YEAR' => PeriodUnit.year,
  _ => PeriodUnit.unknown,
};

/// Parses a period from the SDK's separate multiplier and unit strings.
///
/// Returns `null` when either is missing, as it is for items.
SubscriptionPeriod? parseSubscriptionPeriod({
  required String multiplier,
  required String unit,
}) {
  final count = int.tryParse(multiplier);
  if (count == null || unit.isEmpty) return null;
  return SubscriptionPeriod(count: count, unit: parsePeriodUnit(unit));
}
