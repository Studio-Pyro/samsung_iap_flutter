## 0.1.0

First release. Samsung In-App Purchase SDK 6.5.2 on Android, through the const `SamsungIap` class.

- `initialize` sets the operation mode, which defaults to `OperationMode.production`, and whether
  Samsung shows its own error dialogs.
- `getGalaxyStoreStatus` reports whether Galaxy Store is installed, enabled and genuine, without a
  dialog.
- `getProducts` and `getOwnedProducts` fetch products and the user's owned products.
- `purchase` shows Samsung's payment sheet and accepts obfuscated account and profile IDs.
- `consume` and `acknowledge` finish purchases and return one result per purchase.
- `changeSubscriptionPlan` moves a subscriber between tiers with one of four proration modes.
- `getPromotionEligibility` reports whether a user gets a free trial or an introductory price.
- Every method throws `SamsungIapException`, whose `kind` names what the app does next.
- The plugin checks arguments before it calls Samsung, and reports a bad argument as
  `invalidArgument`.
