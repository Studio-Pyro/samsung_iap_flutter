## 0.1.0

First release. The Android implementation of `samsung_iap_flutter`.

- Bridges Samsung IAP SDK 6.5.2 from Maven Central (`com.samsung.developer:iap:6.5.2`) through
  Pigeon. Requires minSdk 23.
- Runs one Samsung call at a time, because Samsung refuses a payment while another call runs.
- Stops a call that shows no Samsung UI after 30 seconds with `network`. `purchase` and
  `changeSubscriptionPlan` have no timeout.
- Checks that Galaxy Store is installed, enabled and genuine before each call, and throws
  `storeUnavailable` instead of waiting for a callback that never comes.
- Reports a call that Samsung refuses to start as `busy`.
- Throws `storeUpdateRequired` from `acknowledge` on Galaxy Store older than 4.5.90.
- Maps every Samsung error code to a `SamsungIapErrorKind`, and parses the detail code and
  `dialogShown`.
- Ships R8 keep rules for the Samsung IAP classes.
