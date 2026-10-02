import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartPackageName: 'samsung_iap_flutter_android',
    kotlinOut: 'android/src/main/kotlin/dev/studiopyro/samsung_iap_flutter/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'dev.studiopyro.samsung_iap_flutter'),
    copyrightHeader: 'pigeons/copyright.txt',
  ),
)
enum PlatformOperationMode { production, test, testFailure }

enum PlatformStoreStatus { available, notInstalled, disabled, invalid }

enum PlatformOwnedProductFilter { item, subscription, all }

enum PlatformProrationMode {
  instantProratedDate,
  instantProratedCharge,
  instantNoProration,
  deferred,
}

/// `ProductVo` field for field. Kotlin sends a missing string as `""` and
/// Dart does all interpretation.
class PlatformProduct {
  PlatformProduct({
    required this.itemId,
    required this.itemName,
    required this.itemPrice,
    required this.itemPriceString,
    required this.currencyUnit,
    required this.currencyCode,
    required this.itemDesc,
    required this.type,
    required this.subscriptionDurationUnit,
    required this.subscriptionDurationMultiplier,
    required this.tieredSubscriptionYN,
    required this.tieredPrice,
    required this.tieredPriceString,
    required this.tieredSubscriptionDurationUnit,
    required this.tieredSubscriptionDurationMultiplier,
    required this.tieredSubscriptionCount,
    required this.showStartDate,
    required this.showEndDate,
    required this.itemImageUrl,
    required this.itemDownloadUrl,
    required this.freeTrialPeriod,
    required this.json,
  });

  String itemId;
  String itemName;
  double? itemPrice;
  String itemPriceString;
  String currencyUnit;
  String currencyCode;
  String itemDesc;
  String type;
  String subscriptionDurationUnit;
  String subscriptionDurationMultiplier;
  String tieredSubscriptionYN;
  String tieredPrice;
  String tieredPriceString;
  String tieredSubscriptionDurationUnit;
  String tieredSubscriptionDurationMultiplier;
  String tieredSubscriptionCount;
  String showStartDate;
  String showEndDate;
  String itemImageUrl;
  String itemDownloadUrl;
  String freeTrialPeriod;
  String json;
}

/// The `SubscriptionPriceChangeVo` fields the public model uses. The prices
/// are NaN when Samsung sends none.
class PlatformSubscriptionPriceChange {
  PlatformSubscriptionPriceChange({
    required this.subscriptionDurationUnit,
    required this.subscriptionDurationMultiplier,
    required this.startDate,
    required this.originalLocalPrice,
    required this.originalLocalPriceString,
    required this.newLocalPrice,
    required this.newLocalPriceString,
    required this.isConsented,
    required this.priceChangeMode,
  });

  String subscriptionDurationUnit;
  String subscriptionDurationMultiplier;
  String startDate;
  double originalLocalPrice;
  String originalLocalPriceString;
  double newLocalPrice;
  String newLocalPriceString;
  bool isConsented;

  /// The SDK enum constant's name, or `""`.
  String priceChangeMode;
}

/// The `OwnedProductVo` fields the public model uses, with the same rules as
/// [PlatformProduct].
class PlatformOwnedProduct {
  PlatformOwnedProduct({
    required this.itemId,
    required this.itemName,
    required this.itemPrice,
    required this.itemPriceString,
    required this.currencyCode,
    required this.type,
    required this.paymentId,
    required this.purchaseId,
    required this.purchaseDate,
    required this.subscriptionEndDate,
    required this.subscriptionPriceChange,
    required this.acknowledgedStatus,
    required this.obfuscatedAccountId,
    required this.obfuscatedProfileId,
    required this.json,
  });

  String itemId;
  String itemName;
  double? itemPrice;
  String itemPriceString;
  String currencyCode;
  String type;
  String paymentId;
  String purchaseId;
  String purchaseDate;
  String subscriptionEndDate;
  PlatformSubscriptionPriceChange? subscriptionPriceChange;

  /// The SDK enum constant's name, or `""`.
  String acknowledgedStatus;
  String obfuscatedAccountId;
  String obfuscatedProfileId;
  String json;
}

/// The `PurchaseVo` fields the public model uses, with the same rules as
/// [PlatformProduct].
class PlatformPurchase {
  PlatformPurchase({
    required this.itemId,
    required this.itemName,
    required this.itemPrice,
    required this.itemPriceString,
    required this.currencyCode,
    required this.type,
    required this.paymentId,
    required this.purchaseId,
    required this.orderId,
    required this.purchaseDate,
    required this.minorStatus,
    required this.obfuscatedAccountId,
    required this.obfuscatedProfileId,
    required this.json,
  });

  String itemId;
  String itemName;
  double? itemPrice;
  String itemPriceString;
  String currencyCode;
  String type;
  String paymentId;
  String purchaseId;
  String orderId;
  String purchaseDate;

  /// The SDK enum constant's name, or `""`.
  String minorStatus;
  String obfuscatedAccountId;
  String obfuscatedProfileId;
  String json;
}

/// `ConsumeVo` and `AcknowledgeVo`, which share their fields.
class PlatformAckResult {
  PlatformAckResult({
    required this.purchaseId,
    required this.statusCode,
    required this.statusString,
  });

  String purchaseId;
  int statusCode;
  String statusString;
}

@HostApi()
abstract class SamsungIapHostApi {
  void initialize(PlatformOperationMode mode, bool showErrorDialog);

  PlatformStoreStatus getStoreStatus();

  /// [productIds] is comma-separated; empty means every product.
  @async
  List<PlatformProduct> getProductsDetails(String productIds);

  @async
  List<PlatformOwnedProduct> getOwnedList(PlatformOwnedProductFilter filter);

  /// Completes when the user leaves Samsung's payment sheet. No timeout.
  @async
  PlatformPurchase startPayment(
    String itemId,
    String? obfuscatedAccountId,
    String? obfuscatedProfileId,
  );

  /// [purchaseIds] is comma-separated and not empty.
  @async
  List<PlatformAckResult> consumePurchasedItems(String purchaseIds);

  /// [purchaseIds] is comma-separated and not empty. Fails with
  /// `store_update_required` on a Galaxy Store that cannot acknowledge.
  @async
  List<PlatformAckResult> acknowledgePurchases(String purchaseIds);

  /// Completes when the user leaves Samsung's plan-change UI. No timeout.
  @async
  PlatformPurchase changeSubscriptionPlan(
    String oldItemId,
    String newItemId,
    PlatformProrationMode prorationMode,
    String? obfuscatedAccountId,
    String? obfuscatedProfileId,
  );
}
