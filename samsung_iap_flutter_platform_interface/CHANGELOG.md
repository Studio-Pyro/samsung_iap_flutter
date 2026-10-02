## 0.1.0

First release. The platform interface of `samsung_iap_flutter`.

- `SamsungIapFlutterPlatform`, the base class that platform implementations extend.
- Models: `SamsungProduct`, `OwnedProduct`, `SamsungPurchase`, `PurchaseAckResult`,
  `PromotionEligibility`, `SubscriptionPeriod`, `IntroductoryOffer` and `SubscriptionPriceChange`.
  Products, owned products, purchases and eligibility results keep Samsung's JSON in `rawJson`.
- Enums for operation modes, Galaxy Store status, product types, owned-product filters,
  acknowledged and minor status, price changes, proration modes, promotion pricing and
  acknowledge status. A value this version does not know parses to `unknown`.
- `SamsungIapException`, with a `kind`, Samsung's `code` and `detailCode`, and `dialogShown`.
- Dates parse to device-local `DateTime` values.
