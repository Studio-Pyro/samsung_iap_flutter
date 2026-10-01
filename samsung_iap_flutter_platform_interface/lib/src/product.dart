import 'package:flutter/foundation.dart';
import 'package:samsung_iap_flutter_platform_interface/src/enums.dart';

/// A length of time such as one month or three weeks.
@immutable
class SubscriptionPeriod {
  /// Creates a period of [count] times [unit].
  const new({required this.count, required this.unit});

  /// How many [unit]s the period lasts.
  final int count;

  /// The unit of the period.
  final PeriodUnit unit;

  @override
  bool operator ==(Object other) =>
      other is SubscriptionPeriod && other.count == count && other.unit == unit;

  @override
  int get hashCode => Object.hash(count, unit);

  @override
  String toString() => 'SubscriptionPeriod($count ${unit.name})';
}

/// The lower-tier price a subscription charges for its first periods.
@immutable
class IntroductoryOffer {
  /// Creates an introductory offer.
  const new({
    required this.price,
    required this.formattedPrice,
    required this.period,
    required this.cycles,
  });

  /// The offer price in local currency, or `null` if Samsung sent none.
  final double? price;

  /// The offer price formatted for display, for example `£0.99`.
  final String formattedPrice;

  /// The length of one offer period.
  final SubscriptionPeriod period;

  /// How many periods the offer price applies to.
  final int cycles;

  Object get _fields => (price, formattedPrice, period, cycles);

  @override
  bool operator ==(Object other) =>
      other is IntroductoryOffer && other._fields == _fields;

  @override
  int get hashCode => _fields.hashCode;

  @override
  String toString() => 'IntroductoryOffer($formattedPrice x $cycles)';
}

/// A product registered in Seller Portal, as returned by `getProducts`.
@immutable
class SamsungProduct {
  /// Creates a product.
  const new({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.price,
    required this.formattedPrice,
    required this.currencyCode,
    required this.currencySymbol,
    required this.subscriptionPeriod,
    required this.freeTrialDays,
    required this.introductoryOffer,
    required this.availableFrom,
    required this.availableUntil,
    required this.imageUrl,
    required this.downloadUrl,
    required this.rawJson,
  });

  /// The product ID from Seller Portal.
  final String id;

  /// The product title.
  final String name;

  /// The product description.
  final String description;

  /// Whether this is a one-time item or a subscription.
  final SamsungProductType type;

  /// The price in local currency, or `null` if Samsung sent none.
  final double? price;

  /// The price formatted for display, for example `£7.99`.
  final String formattedPrice;

  /// The ISO 4217 currency code, for example `GBP`.
  final String currencyCode;

  /// The currency symbol, for example `£`.
  final String currencySymbol;

  /// The billing period of a subscription. `null` for items.
  final SubscriptionPeriod? subscriptionPeriod;

  /// The length of the free trial in days, or `null` if there is none.
  final int? freeTrialDays;

  /// The lower-tier introductory price, or `null` if there is none.
  final IntroductoryOffer? introductoryOffer;

  /// When the product goes on sale, in device-local time.
  ///
  /// Samsung formats this on the device without a time zone, so treat it as
  /// approximate.
  final DateTime? availableFrom;

  /// When the product stops being on sale, in device-local time.
  ///
  /// Samsung formats this on the device without a time zone, so treat it as
  /// approximate.
  final DateTime? availableUntil;

  /// The product image, if one is registered.
  final Uri? imageUrl;

  /// The product download URL, if one is registered.
  final Uri? downloadUrl;

  /// The JSON payload the SDK received, for fields this model does not
  /// expose and for support logs.
  final String rawJson;

  Object get _fields => (
    id,
    name,
    description,
    type,
    price,
    formattedPrice,
    currencyCode,
    currencySymbol,
    subscriptionPeriod,
    freeTrialDays,
    introductoryOffer,
    availableFrom,
    availableUntil,
    imageUrl,
    downloadUrl,
    rawJson,
  );

  @override
  bool operator ==(Object other) =>
      other is SamsungProduct && other._fields == _fields;

  @override
  int get hashCode => _fields.hashCode;

  @override
  String toString() => 'SamsungProduct($id, $formattedPrice)';
}
