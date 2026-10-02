import 'package:flutter/foundation.dart';
import 'package:samsung_iap_flutter_platform_interface/src/enums.dart';

/// A completed payment, as returned by `purchase`.
///
/// Verify [purchaseId] on your server if you have one, then grant access and
/// consume or acknowledge it.
@immutable
class SamsungPurchase {
  /// Creates a purchase.
  const new({
    required this.productId,
    required this.name,
    required this.purchaseId,
    required this.paymentId,
    required this.orderId,
    required this.type,
    required this.purchaseDate,
    required this.minorStatus,
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

  /// Samsung's order ID.
  final String orderId;

  /// Whether this is a one-time item or a subscription.
  final SamsungProductType type;

  /// When the product was bought, in device-local time.
  ///
  /// Samsung formats this on the device without a time zone, so treat it as
  /// approximate. Samsung's server receipt is the source of truth.
  final DateTime? purchaseDate;

  /// Whether Samsung identifies the buyer as a minor.
  final MinorStatus minorStatus;

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

  Object get _fields => (
    productId,
    name,
    purchaseId,
    paymentId,
    orderId,
    type,
    purchaseDate,
    minorStatus,
    obfuscatedAccountId,
    obfuscatedProfileId,
    price,
    formattedPrice,
    currencyCode,
    rawJson,
  );

  @override
  bool operator ==(Object other) =>
      other is SamsungPurchase && other._fields == _fields;

  @override
  int get hashCode => _fields.hashCode;

  @override
  String toString() => 'SamsungPurchase($productId, $purchaseId, $orderId)';
}
