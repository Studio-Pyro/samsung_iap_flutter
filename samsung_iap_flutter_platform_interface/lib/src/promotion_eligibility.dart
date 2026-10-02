import 'package:flutter/foundation.dart';
import 'package:samsung_iap_flutter_platform_interface/src/enums.dart';

/// The offer one subscription would give the user, as returned by
/// `getPromotionEligibility`.
@immutable
class PromotionEligibility {
  /// Creates an eligibility.
  const new({
    required this.productId,
    required this.pricing,
    required this.rawJson,
  });

  /// The subscription's product ID from Seller Portal.
  final String productId;

  /// The offer the user would get on subscribing now.
  final PromotionPricing pricing;

  /// The JSON payload the SDK received, for fields this model does not
  /// expose and for support logs.
  final String rawJson;

  Object get _fields => (productId, pricing, rawJson);

  @override
  bool operator ==(Object other) =>
      other is PromotionEligibility && other._fields == _fields;

  @override
  int get hashCode => _fields.hashCode;

  @override
  String toString() => 'PromotionEligibility($productId, ${pricing.name})';
}
