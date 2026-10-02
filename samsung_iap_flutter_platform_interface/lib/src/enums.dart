/// How Samsung IAP processes requests.
///
/// Use [test] or [testFailure] only while the app is in the Registering or
/// Updating state in Seller Portal. A build that ships in [test] mode gives
/// license testers free products and shows everyone else an error.
enum OperationMode {
  /// Real transactions with real results. The default.
  production,

  /// Payments always succeed and nothing is charged. Only license testers can
  /// buy.
  test,

  /// Every request fails, so error handling can be tested.
  testFailure,
}

/// Whether Galaxy Store can serve in-app purchases on this device.
enum GalaxyStoreStatus {
  /// Galaxy Store is installed, enabled and genuine.
  available,

  /// Galaxy Store is missing, or installed at a version the SDK cannot use.
  notInstalled,

  /// Galaxy Store is installed but disabled.
  disabled,

  /// The installed Galaxy Store does not carry Samsung's signature.
  invalid,
}

/// The kind of product registered in Seller Portal.
enum SamsungProductType {
  /// A one-time item. Consume it to allow a repurchase, or acknowledge it as a
  /// permanent unlock.
  item,

  /// An auto-recurring subscription.
  subscription,

  /// A type this version of the plugin does not know.
  unknown,
}

/// The unit of a subscription period.
enum PeriodUnit {
  /// One week.
  week,

  /// One calendar month.
  month,

  /// One calendar year.
  year,

  /// A unit this version of the plugin does not know.
  unknown,
}

/// Which owned products to fetch.
enum OwnedProductFilter {
  /// One-time items only.
  item,

  /// Subscriptions only.
  subscription,

  /// Items and subscriptions.
  all,
}

/// Whether an owned product has been acknowledged.
enum AcknowledgedStatus {
  /// Galaxy Store did not report the status, for example because it is too
  /// old.
  unsupported,

  /// Not acknowledged yet.
  notAcknowledged,

  /// Already acknowledged.
  acknowledged,

  /// A status this version of the plugin does not know.
  unknown,
}

/// The kind of a scheduled subscription price change.
enum PriceChangeMode {
  /// The price goes up, and the user must agree to the new price to keep the
  /// subscription.
  increaseConsentRequired,

  /// The price goes up without the user having to agree.
  increaseNoConsentRequired,

  /// The price goes down.
  decrease,

  /// A mode this version of the plugin does not know.
  unknown,
}

/// Whether Samsung identifies the buyer as a minor.
enum MinorStatus {
  /// Samsung could not tell.
  unidentified,

  /// The buyer is not a minor.
  notMinor,

  /// The buyer is a minor.
  minor,

  /// A status this version of the plugin does not know.
  unknown,
}

/// Samsung's outcome for one purchase of a consume or acknowledge call.
enum AckStatus {
  /// The purchase is now consumed or acknowledged.
  success,

  /// Samsung knows no purchase with this ID.
  invalidPurchaseId,

  /// The order behind the purchase failed.
  failedOrder,

  /// The product's type does not allow this call.
  invalidProductType,

  /// An earlier call already consumed or acknowledged the purchase.
  alreadyProcessed,

  /// Samsung does not let the signed-in user change this purchase.
  unauthorized,

  /// Samsung hit an unexpected error. Safe to retry.
  serviceError,

  /// A status this version of the plugin does not know. See
  /// `PurchaseAckResult.statusCode`.
  unknown,
}

/// How Samsung bills a subscription plan change, and when it takes effect.
///
/// An upgrade moves to a tier that costs more or the same. A downgrade moves
/// to a tier that costs less, and Samsung always runs it as [deferred].
enum ProrationMode {
  /// Changes the plan now. The value left on the current plan becomes time on
  /// the new plan, so the renewal date moves.
  instantProratedDate,

  /// Changes the plan now and charges the price difference for the rest of
  /// the period. The renewal date stays the same. Upgrades only.
  instantProratedCharge,

  /// Changes the plan now and charges the new price from the next renewal.
  /// Upgrades only.
  instantNoProration,

  /// Changes the plan at the next renewal. Until then, the user cannot change
  /// the plan again.
  deferred,
}
