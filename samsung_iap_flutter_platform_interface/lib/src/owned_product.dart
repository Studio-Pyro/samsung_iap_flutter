import 'package:flutter/foundation.dart';
import 'package:samsung_iap_flutter_platform_interface/src/enums.dart';
import 'package:samsung_iap_flutter_platform_interface/src/product.dart';

/// A price change Samsung has scheduled for an owned subscription.
@immutable
class SubscriptionPriceChange {
  /// Creates a price change.
  const new({
    required this.mode,
    required this.consented,
    required this.startDate,
    required this.originalPrice,
    required this.originalFormattedPrice,
    required this.newPrice,
    required this.newFormattedPrice,
    required this.period,
  });

  /// Whether the price goes up or down, and whether the user must agree.
  final PriceChangeMode mode;

  /// Whether the user has agreed to the new price.
  final bool consented;

  /// When the new price applies, in device-local time, or `null` if Samsung
  /// sent no date it could read.
  final DateTime? startDate;

  /// The current price in local currency, or `null` if Samsung sent none.
  final double? originalPrice;

  /// The current price formatted for display.
  final String originalFormattedPrice;

  /// The new price in local currency, or `null` if Samsung sent none.
  final double? newPrice;

  /// The new price formatted for display.
  final String newFormattedPrice;

  /// The billing period the prices are for, or `null` if Samsung sent none.
  final SubscriptionPeriod? period;

  Object get _fields => (
    mode,
    consented,
    startDate,
    originalPrice,
    originalFormattedPrice,
    newPrice,
    newFormattedPrice,
    period,
  );

  @override
  bool operator ==(Object other) =>
      other is SubscriptionPriceChange && other._fields == _fields;

  @override
  int get hashCode => _fields.hashCode;

  @override
  String toString() =>
      'SubscriptionPriceChange(${mode.name}, '
      '$originalFormattedPrice -> $newFormattedPrice, consented: $consented)';
}

/// A product the user owns, as returned by `getOwnedProducts`.
///
/// The list includes cancelled subscriptions until their period ends.
@immutable
class OwnedProduct {
  /// Creates an owned product.
  const new({
    required this.productId,
    required this.name,
    required this.purchaseId,
    required this.paymentId,
    required this.type,
    required this.purchaseDate,
    required this.subscriptionEndDate,
    required this.acknowledgedStatus,
    required this.priceChange,
    required this.obfuscatedAccountId,
    required this.obfuscatedProfileId,
    required this.price,
    required this.formattedPrice,
    required this.currencyCode,
    required this.rawJson,
  });

  /// The product ID from Seller Portal.
  final String productId;

  /// The product title.
  final String name;

  /// The ID that consume, acknowledge and server-side receipt verification
  /// take.
  final String purchaseId;

  /// Samsung's payment ID.
  final String paymentId;

  /// Whether this is a one-time item or a subscription.
  final SamsungProductType type;

  /// When the product was bought, in device-local time.
  ///
  /// Samsung formats this on the device without a time zone, so treat it as
  /// approximate. Samsung's server receipt is the source of truth.
  final DateTime? purchaseDate;

  /// When the current subscription period ends, in device-local time. `null`
  /// for items.
  ///
  /// Samsung formats this on the device without a time zone, so treat it as
  /// approximate. Do not build expiry logic on it. Samsung's server receipt is
  /// the source of truth.
  final DateTime? subscriptionEndDate;

  /// Whether the purchase has been acknowledged.
  final AcknowledgedStatus acknowledgedStatus;

  /// A scheduled price change for a subscription, or `null` if there is none.
  final SubscriptionPriceChange? priceChange;

  /// The obfuscated account ID passed to the purchase, if any.
  final String? obfuscatedAccountId;

  /// The obfuscated profile ID passed to the purchase, if any.
  final String? obfuscatedProfileId;

  /// The price in local currency, or `null` if Samsung sent none.
  final double? price;

  /// The price formatted for display, for example `£7.99`.
  final String formattedPrice;

  /// The ISO 4217 currency code, for example `GBP`.
  final String currencyCode;

  /// The JSON payload the SDK received, for fields this model does not
  /// expose and for support logs.
  final String rawJson;

  /// The Galaxy Store page where the user manages this subscription and
  /// agrees to a price change. Only subscriptions have a detail page.
  ///
  /// A string rather than a [Uri], because [Uri] lowercases the host and
  /// Samsung documents it as `SubscriptionDetail`. Open it with an API that
  /// takes a string, such as url_launcher's `launchUrlString`, not
  /// `launchUrl(Uri.parse(link))`.
  String get subscriptionDetailLink =>
      'samsungapps://SubscriptionDetail?purchaseId='
      '${Uri.encodeQueryComponent(purchaseId)}';

  Object get _fields => (
    productId,
    name,
    purchaseId,
    paymentId,
    type,
    purchaseDate,
    subscriptionEndDate,
    acknowledgedStatus,
    priceChange,
    obfuscatedAccountId,
    obfuscatedProfileId,
    price,
    formattedPrice,
    currencyCode,
    rawJson,
  );

  @override
  bool operator ==(Object other) =>
      other is OwnedProduct && other._fields == _fields;

  @override
  int get hashCode => _fields.hashCode;

  @override
  String toString() =>
      'OwnedProduct($productId, $purchaseId, ${acknowledgedStatus.name})';
}
