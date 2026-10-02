## 0.1.0

First release. The Android implementation of `samsung_iap_flutter`.

- Bridges Samsung IAP SDK 6.5.2 from Maven Central (`com.samsung.developer:iap:6.5.2`) through
  Pigeon. Requires minSdk 23.
- Runs one Samsung call at a time, because Samsung refuses a payment while another call runs.
- Stops a call that shows no Samsung UI after 30 seconds with `network`. `purchase` and
  `changeSubscriptionPlan` have no timeout.
- Checks that Galaxy Store is installed, enabled and genuine before each call to Samsung, and
  throws `storeUnavailable` instead of waiting for a callback that never comes.
- Reports a call that Samsung refuses to start as `busy`.
- Throws `storeUpdateRequired` from `acknowledge` on Galaxy Store older than 4.5.90.
- Maps every Samsung error code to a `SamsungIapErrorKind`, and parses the detail code and
  `dialogShown`. A raw server code, such as 9201 from a service call, maps like -1002 with that
  detail code. A detail code of 9201, 9202, 9207, 9224, 9134 or 9259 refines a -1002 or a raw code
  to its specific kind.
- Parses Samsung's strings into the public models. A value this version does not know parses to
  `unknown`, `Y` and `N` parse to `bool`, and dates parse to device-local `DateTime` values.
- Ships an R8 keep rule for Samsung's IAP service (AIDL) classes.
