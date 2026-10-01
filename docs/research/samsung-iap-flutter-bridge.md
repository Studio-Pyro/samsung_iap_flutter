# Samsung IAP SDK 6.5.2 ↔ Flutter federated plugin: research notes

Researched 2026-09-30. Scope: what it takes to turn this VGV federated-plugin template into a typed, reusable bridge to Samsung In-App Purchase SDK 6.5.2 on Android. Originally framed as: the target apps use RevenueCat for App Store and Google Play, and call Samsung IAP directly in their Galaxy Store builds. **Updated 2026-10-01:** Studio Pyro's own apps will use RevenueCat's Galaxy support through a `purchases_flutter` fork, and this plugin will be published for everyone else. See §10.

**Citation convention.** Bracketed IDs such as `[H §Purchase]` point to the [Sources](#12-sources) list; `§` names the section on that page. `[AAR]` means I read it off the compiled `com.samsung.developer:iap:6.5.2` artifact from Maven Central (`javap` over `classes.jar` plus the AAR manifest). That is primary evidence of what 6.5.2 does, but it is not Samsung documentation, and internal behavior can change in a patch release. Anything marked **Inference** is my reasoning, not something I saw in a source.

**Could not access:** `https://developer.samsung.com/iap/sdk-integration/overview.html` and `/usage.html`. Both redirect to Samsung Account login (`HTTP 302 → /login?...`). Samsung's own metadata repo confirms that the SDK Integration Guide is login-only [META §Restricted Resources]. Whatever that guide prescribes (for example ProGuard rules or the exact Gradle snippet) is **not verified** here. §3 covers what I could establish without it.

---

## 0. Key findings

1. **6.5.2 is on Maven Central** as `com.samsung.developer:iap:6.5.2` (packaging `aar`, no transitive dependencies). The release is dated 2026-05-18 [MVN] [META §Artifact Information] [RN §6.5.2]. Nothing needs vendoring into `libs/`, which removes the prior art's biggest problem (§4).
2. **Some calls fail silently.** From [AAR] bytecode: `startPayment()` and `changeSubscriptionPlan()` **return `false` and never call the listener** when another SDK operation is in progress. They do the same on invalid input (empty id, obfuscated ID longer than 64 chars or shaped like an email, profile ID without account ID). `getProductsDetails()` returns `void` and **never calls the listener** if Galaxy Store is missing, disabled, or has an invalid signature. A naive bridge will hang its Futures. The plugin must treat `false` as an error, validate inputs first, and pre-check Galaxy Store (§6.3).
3. **Inquiry calls are queued, payments are not.** 6.5.2 queues `getOwnedList`, `getProductsDetails`, `consumePurchasedItems`, `acknowledgePurchases` and `getPromotionEligibility` behind the running operation [AAR `ServiceScheduler`, `InProgressHandler`] [RN §6.5.2: "executed sequentially after the payment is completed"]. A payment started while an inquiry is running is refused, not queued [AAR log string: "startPayment canceled: Another operation in progress. Payment skipped."]. The fix is a small Dart-side serial queue.
4. **No Activity needed.** `IapHelper` keeps `context.getApplicationContext()` and starts its own `PaymentActivity` with `FLAG_ACTIVITY_NEW_TASK` (`0x10000000`) [AAR `IapHelper.executePayment`]. The plugin can be a plain `FlutterPlugin`; `ActivityAware` is not required. This differs from `in_app_purchase_android` [IAPA-PLUGIN].
5. **There is no `dispose()` in 6.5.2 `IapHelper`** [AAR: full public method list in §2.2]. Nothing to call in `onDetachedFromEngine` beyond unregistering Pigeon.
6. **Dates are local-time strings.** The SDK reads epoch-millis fields from the server JSON and rewrites them to `"yyyy-MM-dd HH:mm:ss"` in the device's default timezone. The UTC value is gone, even from `getJsonString()` [AAR `BaseVo.getDateString`, `OwnedProductVo.<init>`]. Treat on-device dates as approximate; the server receipt API returns GMT [VERIFY §Response].
7. **The docs and the AAR disagree on error codes.** The docs list `IAP_ERROR_INVALID_ACCESS_TOKEN (-1015)` [H §Response code]. The AAR defines `IAP_ERROR_NEED_SA_LOGIN = -1014` and no -1015 [AAR `HelperDefine`]. Map both, and keep the raw code.
8. **The template does not compile today.** `Messages.g.kt` (Pigeon 28.1.0) declares `suspend fun getPlatformName()`, but `SamsungIapFlutterPlugin.kt` implements a callback signature. Pigeon 28.0.0 made `@async` generate `suspend` functions [PIGEON-CL §28.0.0]. The generated file also imports `kotlinx.coroutines`, which `android/build.gradle` does not declare.
9. **Consumable vs non-consumable is deprecated in 6.5.0.** Registering non-consumable items in Seller Portal ended on 2026-01-14 [H §Get user-owned products, `getIsConsumable()`] [PG]. The app must decide between `consumePurchasedItems()` and `acknowledgePurchases()` per product. The plugin cannot infer it.
10. **Samsung requires a package name that differs from the app's listing in other stores** [INTEG §Create a project with a unique package name]. Each Flutter app therefore needs a Galaxy-specific `applicationId` (flavor), not only a different Dart entry point.

---

## 1. Starting point: repo audit

Files read: every Dart, Gradle, Kotlin and pubspec file under the three packages, plus the example app manifests and `.github/workflows/samsung_iap_flutter_android.yaml`.

| Item | Current state | Needed |
|---|---|---|
| Kotlin package / namespace | `com.example.verygoodcore` (template placeholder) in `samsung_iap_flutter_android/android/build.gradle` (`group`, `namespace`), in the Kotlin source path `android/src/main/kotlin/com/example/verygoodcore/`, in `samsung_iap_flutter_android/pubspec.yaml` (`flutter.plugin.platforms.android.package`), in `pigeons/messages.dart` (`kotlinOut`), and in the example app (`namespace`/`applicationId = "com.example.verygoodcore.example"`) | Rename everywhere (S0) |
| Copyright header | `// Copyright (c) 2026, Com Example Verygoodcore` in the generated files (from `pigeons/copyright.txt`) | Fix |
| Pigeon Kotlin package | `KotlinOptions()` has no `package:`, so `Messages.g.kt` has no `package` line. Generated types land in the root package, which is why the plugin does `import SamsungIapFlutterApi` | Set `KotlinOptions(package: '<pkg>')` |
| Pigeon/Kotlin mismatch | `Messages.g.kt`: `suspend fun getPlatformName(): String?`. Plugin: `override fun getPlatformName(callback: (Result<String?>) -> Unit)`. **Does not compile.** | Implement `suspend` (or use `@asyncCallback`) |
| Coroutines dependency | The generated code imports `kotlinx.coroutines.*` and wraps handlers in `CoroutineScope(Dispatchers.Main).launch`. Not declared in `build.gradle` | Add `org.jetbrains.kotlinx:kotlinx-coroutines-android`. **Inference:** Flutter does not supply it; other Pigeon-28 plugins in the local pub cache declare it explicitly |
| `minSdkVersion` | 19 | ≥ 23: the AAR manifest has `<uses-sdk android:minSdkVersion="23"/>` [AAR], and docs say ≥ API 23 since 6.1.1 [INTEG] [RN §6.1.1]. Flutter 3.47.5's default app minSdk is 24 [FLUTTER-EXT] |
| `compileSdk` | 34 | 36 (Flutter 3.47.5 default [FLUTTER-EXT]). The prior art got build warnings with an old compileSdk [GENO-ISSUE4] |
| Java target | 1.8 | 11 or 17 (the example app already uses 11) |
| Plugin manifest | Empty `<manifest/>` | Add the `BILLING` and `INTERNET` permissions (§3.2) |
| Platform interface default | `MethodChannelSamsungIapFlutter` on channel `samsung_iap_flutter`, which nothing on Android handles | Delete it and make the base-class methods throw `UnimplementedError`. The Android package registers itself via `dartPluginClass` |
| Kotlin tests | `build.gradle` has `testImplementation kotlin-test`, `mockito-core:5.0.0` and `useJUnitPlatform()`, but no JUnit 5 engine, and there is no `src/test` | Add `kotlin-test-junit5` (or JUnit Jupiter) and `kotlinx-coroutines-test` (**Inference:** the JUnit Platform needs an engine on the classpath) |
| CI | VGV `flutter_package.yml` for each package (Dart tests, pana) | Add a Gradle unit-test job for the Kotlin side (§8) |
| Example | Fluttium flow `flows/test_platform_name.yaml` and `actions/check_platform_name/` that exercise `getPlatformName` | Replace or delete |
| pub.dev names | `samsung_iap_flutter`, `samsung_iap_flutter_android` and `samsung_iap_flutter_platform_interface` all returned HTTP 404 from `pub.dev/api/packages/<name>` on 2026-09-30 (free at that time) | Decide before publishing |

---

## 2. SDK 6.5.2 surface

### 2.1 Artifact facts

- Coordinates: `com.samsung.developer:iap:6.5.2`, the only version on Maven Central (`maven-metadata.xml`, `lastUpdated 20260518024111`). The POM has an empty `<dependencies>` block. The Maven Central AAR sha1 `4804df7d068a7683dbb629584d4aa87c6989bfe7` matched the published `.sha1` [MVN].
- Samsung's metadata repo says the SDK "is provided as a pre-compiled binary via the Samsung Maven Repository" and gives group `com.samsung.developer`, artifact `iap` and latest version `6.5.2` [META]. The artifact resolves from Maven Central. I found no separate Samsung-hosted repo URL.
- Release note: "Since Samsung IAP SDK 6.5.2, it has been distributed through a public repository" [RN §6.5.2]. Earlier versions were AAR downloads behind a login (since 6.1.1 an AAR rather than a project) [RN §6.1.1], and the codelab still uses `libs/samsung-iap-6.5.0.aar` with `implementation fileTree(dir: 'libs', include: ['*.aar'])` [CL §Initialize the Samsung IAP SDK].
- `-sources.jar` and `-javadoc.jar` exist on Maven Central but are 307-byte placeholders [MVN]. There are no real sources or javadoc; javadoc.io has not synced the artifact.
- `BuildConfig.VERSION_NAME = "6.5.2"`, but `BUILD_TYPE = "debug"`. The AAR's manifest still says `android:versionName="6.1.2"` [AAR]. Both look like cosmetic packaging leftovers. **Inference:** a debug build type may mean verbose `LogUtil` logging in release apps.
- License: the binary is governed by the Samsung IAP License Agreement, and the metadata/POM by Apache-2.0 [META §License]. **Inference:** depending on it through Maven, rather than redistributing it, avoids the question of repackaging the binary inside a pub package.
- 6.5.x changes [RN]:
  - 6.5.2: fixed "listener not called when exception occurs"; inquiry APIs called during a payment now run sequentially after it; better logging.
  - 6.5.0: `obfuscatedAccountId`/`obfuscatedProfileId` added to `startPayment()`/`changeSubscriptionPlan()` and returned by `getOwnedList()`; dialog-overlap handling for targetSdk ≥ 35 on Android 15+.
  - 6.4.0: `acknowledgePurchases()`, `AcknowledgedStatus`, `MinorStatus`; `passThroughParam` deprecated.
  - 6.3.0: `changeSubscriptionPlan()`, `SubscriptionPriceChangeVo`.
  - 6.2.0: `getPromotionEligibility()`.
  - 6.1.1: AAR distribution, minSdk 23, targetSdk 34.

### 2.2 `IapHelper` public API (6.5.2)

Package `com.samsung.android.sdk.iap.lib.helper.IapHelper`. It extends `com.samsung.android.sdk.iap.lib.constants.HelperDefine`. Note that in 6.5.2, `HelperDefine` is in `.constants`; the prior art imports it from `.helper`, which is an older layout [GENO] [AAR]. The complete list of public methods from `javap` [AAR]:

| Method (exact signature) | Returns | Listener → callback | Notes |
|---|---|---|---|
| `static IapHelper getInstance(Context)` | singleton | – | Stores `context.getApplicationContext()`. Later calls replace the stored context [AAR]. Docs: call before any request [H §Instantiate]. |
| `void setOperationMode(HelperDefine.OperationMode)` | – | – | Defaults to `OPERATION_MODE_PRODUCTION` if never called [H §Set the IAP operation mode] [AAR ctor]. Global to the process singleton. |
| `void getProductsDetails(String productIds, OnGetProductsDetailsListener)` | **void** | `onGetProducts(ErrorVo, ArrayList<ProductVo>)` | `""` means all products; otherwise comma-delimited IDs [H §Get in-app product details]. The docs example uses `"Nuclear, Claymore, SpeedUp"` with spaces [H]. List order is not guaranteed [FAQ Q10]. If Galaxy Store is invalid, it logs and returns **without calling the listener** [AAR]. |
| `boolean getOwnedList(String productType, OnGetOwnedListListener)` | `true` = sent | `onGetOwnedProducts(ErrorVo, ArrayList<OwnedProductVo>)` | `productType` ∈ `"item"`, `"subscription"`, `"all"` (`PRODUCT_TYPE_*`) [H §Get user-owned products] [AAR]. **Must be called on every app launch** [H] [FLOW]. Includes cancelled subscriptions until the period ends [H]. |
| `boolean startPayment(String itemId, String obfuscatedAccountId, String obfuscatedProfileId, OnPaymentListener)` | `true` = sent | `onPayment(ErrorVo, PurchaseVo)` | Current overload. Obfuscated IDs are optional, "up to 64 bytes", PII in cleartext "may be blocked", and a profile ID requires an account ID [H §Purchase an in-app product]. The SDK enforces `String.length() ≤ 64` and rejects values matching an email regex [AAR `validateObfuscatedIdLengthAndFormat`]. |
| `boolean startPayment(String itemId, String passThroughParam, OnPaymentListener)` | | | Deprecated since 6.4.0 [H]. |
| `boolean startPayment(String itemId, OnPaymentListener)` | | | Undocumented overload [AAR]. |
| `boolean consumePurchasedItems(String purchaseIds, OnConsumePurchasedItemsListener)` | `true` = sent | `onConsumePurchasedItems(ErrorVo, ArrayList<ConsumeVo>)` | Comma-delimited purchase IDs. Batch them in one call: Samsung recommends one call "to avoid system overload or malfunction" [H §Notify Samsung IAP]. Per-item status is in `ConsumeVo.getStatusCode()`, even when some items fail [H]. |
| `boolean acknowledgePurchases(String purchaseIds, OnAcknowledgePurchasesListener)` | `true` = sent | `onAcknowledgePurchases(ErrorVo, ArrayList<AcknowledgeVo>)` | For non-consumables and subscriptions [H]. Returns `false` without calling back if the Galaxy Store version is below 459001000 (log: "Galaxy Store must be updated to version 4.5.90 or higher.") [AAR `HelperUtil.isAcknowledgeAvailable`]. |
| `boolean getPromotionEligibility(String itemIds, OnGetPromotionEligibilityListener)` | `true` = sent | `onGetPromotionEligibility(ErrorVo, ArrayList<PromotionEligibilityVo>)` | Subscription IDs, comma-delimited [H §Get promotion eligibility]. |
| `boolean changeSubscriptionPlan(String oldItemId, String newItemId, HelperDefine.ProrationMode, String obfuscatedAccountId, String obfuscatedProfileId, OnChangeSubscriptionPlanListener)` | `true` = sent | `onChangeSubscriptionPlan(ErrorVo, PurchaseVo)` | Current overload [H §Change subscription plan]. A passThrough overload is deprecated since 6.4.0; a 4-argument overload is undocumented [AAR]. Changes are between tiers "of the same subscription" [SUB-PLAN]. |
| `String getVersionName()`, `int getVersionCode()` | | | Undocumented [AAR]. |
| `boolean getShowErrorDialog()`, `void setShowErrorDialog(boolean)` | | | Undocumented. **Default `true`** (ctor sets `mShowErrorDialog = 1`) [AAR]. `ErrorVo.isShowDialog()` reports whether the SDK showed its own error dialog [H §ErrorVo]. |
| `String getPackageName()`, `void setPackageName(String)` | | | Undocumented, default `""` [AAR]. **Inference:** used for Instant Games bridging (`IAP_INSTANTGAME_BRIDGE_NAME` constant). Do not expose. |

**No `dispose()`** on `IapHelper` in 6.5.2. There is a static `ServiceBinder.dispose()` in an internal package [AAR]. Do not call it.

**Return value `true`/`false`.** Docs: `true` means "The request was sent to server successfully and the result will be sent to [the] listener"; `false` means "The request was not sent to server and was not processed" [H, every method]. The docs do not say that no callback follows `false`. [AAR] shows the `false` paths return before the listener is stored or invoked. **Treat `false` as terminal.**

### 2.3 Threading, Activity, concurrency (from [AAR] unless noted)

- **Activity.** Payment and plan change build an `Intent(context, PaymentActivity/ChangeSubscriptionPlanActivity)` with `FLAG_ACTIVITY_NEW_TASK` and call `applicationContext.startActivity()`. No caller Activity is used. The SDK's four activities (`DialogActivity`, `CheckPackageActivity`, `PaymentActivity`, `ChangeSubscriptionPlanActivity`, theme `Theme.Empty`) are declared in the AAR manifest and merge automatically.
- **Service.** `ServiceBinder` binds to `com.sec.android.app.samsungapps / com.samsung.android.iap.service.IAPService` over AIDL (`IAPConnector`, `IAPServiceCallback`).
- **Callback thread.** Inquiry work runs in `BaseTask extends android.os.AsyncTask`, and `PaymentActivity` invokes the payment listener. **Inference:** all listeners fire on the main thread, via `AsyncTask.onPostExecute` or the Activity. Pigeon-28 `suspend` host handlers already run on `Dispatchers.Main` (generated `CoroutineScope(Dispatchers.Main).launch`, see the repo's `Messages.g.kt`), so both sides stay on main.
- **Concurrency.**
  - A process-wide `InProgressHandler` flag guards everything. Each inquiry is `ServiceScheduler.addService(...)`, then `setStartFlag()`. If the flag is already set it throws `IapInProgressException`, which the method catches, logging "`<method>` queued: will execute after current operation completes", and **returns `true`**. The queued service runs later.
  - `startPayment`/`changeSubscriptionPlan` call `setStartFlag()` first. On `IapInProgressException` they log "startPayment canceled: Another operation in progress. Payment skipped." and **return `false`**. No listener call.
  - Only one `OnPaymentListener` and one `OnChangeSubscriptionPlanListener` are held, in the singleton `HelperListenerManager`.
- **Galaxy Store check.**
  - Every inquiry calls `HelperUtil.isGalaxyStoreValid(context)`, which classifies the store as not installed, disabled, or invalid signature (signature hash `2040106259`). On failure it **launches `CheckPackageActivity`**, a dialog offering to install, enable or update the store, and returns `false`. The method then throws internally and returns `false`; for `getProductsDetails` it simply returns (void).
  - Public static helpers with no dialog side effect exist: `HelperUtil.isInstalledAppsPackage(Context)`, `isEnabledAppsPackage(Context)` and `isValidAppsPackage(Context)`. They are public but live in an internal-looking package (`.lib.util`), so treat them as unstable.
- **Galaxy Store version gates** (`packageInfo.versionCode`): acknowledge needs ≥ 459001000; obfuscated IDs are sent natively only if ≥ 459601000, otherwise folded into a base64 JSON passthrough; `isRequestServiceApiAvailable` checks ≥ 460101000.
- **Process death.** Listeners live in static fields, so they are lost if the process dies mid-purchase. Samsung's remedy is to call `getOwnedList()` and look for the product [FAQ Q12] [H §Get user-owned products "Requirement"].

### 2.4 Operation modes

`HelperDefine.OperationMode` values: `OPERATION_MODE_PRODUCTION`, `OPERATION_MODE_TEST`, `OPERATION_MODE_TEST_FAILURE` [H §Set the IAP operation mode] [AAR].

| Mode | Behavior | Source |
|---|---|---|
| PRODUCTION (default) | Real transactions and real results. Only products bought in PRODUCTION count as owned. In a Closed Beta installed from the beta URL, license testers are not charged; outside a beta they are | [H] [TG-MODES §Production mode] |
| TEST | Payment "always succeeds", with no financial transaction. Only products bought in TEST count as owned. **Only license testers can buy**; others get an error (detail `100010`). The payment sheet shows "Sandbox". Non-consumables can be repurchased every 10 min, subscription periods and 1-day grace periods take 10 min, and subscriptions auto-cancel after 12 renewals | [H] [H §Response code 100010] [TG-MODES §Test mode] [TG-TESTERS] |
| TEST_FAILURE | "All IAP SDK requests fail". Detail codes 9000 (getOwnedList), 9005 (consume), 9013 (getProductsDetails), 9014 (startPayment), all under -1002 | [H] [H §Response code] |

Rules:
- Use TEST/TEST_FAILURE "only if the app status in Seller Portal is Registering or Updating" [H §Set the IAP operation mode Caution].
- A build submitted in TEST mode gives licensed users free products and shows everyone else an error [SUBMIT §Check the operation mode] [TG-PROD].
- **Plugin implication:** the default must be PRODUCTION, and the mode must be an explicit per-build choice by the app. The prior art defaults to TEST (§4).

### 2.5 Product types

- Seller Portal types: **item** (one-time) and **subscription** (auto-recurring) [PG] [INTEG §To register an app].
- The consumable/non-consumable split is deprecated. "The ability to register non-consumable types will end on January 14, 2026. After registering the Item type, please call either the consumePurchasedItems() or acknowledgePurchases() method based on if the item can be repurchased or not." [PG]
- `getIsConsumable()` is deprecated since 6.5.0 [H]. In the AAR it returns `java.lang.Boolean` (nullable), computed from JSON `mConsumableYN == "Y"` [AAR `BaseVo`].
- Subscriptions: one optional free trial (7–999 days [H §ProductVo getFreeTrialPeriod]), 1–100 optional lower-tier (introductory) periods, and regular-tier periods [TG-SUBS]. Duration units are `YEAR`, `MONTH`, `WEEK` [H §ProductVo].
- The seller cannot disable auto-renew [FAQ Q07].

### 2.6 Value objects

Getter types come from [AAR]; meanings from [H] sections for `OwnedProductVo`, `ProductVo`, `PurchaseVo`, `ConsumeVo/AcknowledgeVo`, `PromotionEligibilityVo`, `SubscriptionPriceChangeVo` and `ErrorVo`. The JSON keys are what the VO constructor reads [AAR]. **Missing strings become `""` because the SDK uses `JSONObject.optString`** [AAR], so the plugin must normalize `""` to `null` for optional fields.

**Common base (`BaseVo`)**, shared by `ProductVo`, `OwnedProductVo` and `PurchaseVo`:

| Getter | Type | JSON key | Meaning |
|---|---|---|---|
| `getItemId()` | String | `mItemId` | product ID |
| `getItemName()` | String | `mItemName` | title |
| `getItemPrice()` | `java.lang.Double` | `mItemPrice` (optDouble) | local price, e.g. 7.99 |
| `getItemPriceString()` | String | `mItemPriceString` | formatted price, e.g. "£7.99" or "66815₫"; drops ".00" for whole numbers |
| `getCurrencyUnit()` | String | `mCurrencyUnit` | currency symbol |
| `getCurrencyCode()` | String | `mCurrencyCode` | ISO 4217 code |
| `getItemDesc()` | String | `mItemDesc` | description |
| `getType()` | String | `mType` | `"item"` or `"subscription"` |
| `getIsConsumable()` | `java.lang.Boolean` | `mConsumableYN` | **deprecated 6.5.0** |

**`ProductVo`** (`getProductsDetails`) adds:

| Getter | Type | Meaning |
|---|---|---|
| `getSubscriptionDurationUnit()` | String | `YEAR`/`MONTH`/`WEEK` (subscriptions) |
| `getSubscriptionDurationMultiplier()` | String | numeric multiple, e.g. "1" |
| `getTieredSubscriptionYN()` | String | `"Y"` if it has lower-tier periods |
| `getTieredPrice()`, `getTieredPriceString()` | String | lower-tier price (the numeric one is a *String*) |
| `getTieredSubscriptionDurationUnit()`, `getTieredSubscriptionDurationMultiplier()` | String | lower-tier period |
| `getTieredSubscriptionCount()` | String | number of lower-tier periods |
| `getShowStartDate()`, `getShowEndDate()` | String | sale window, "YYYY-MM-DD HH:mm:ss" |
| `getItemImageUrl()`, `getItemDownloadUrl()` | String | URLs |
| `getFreeTrialPeriod()` | String | days (7–999) |
| `getReserved1()`, `getReserved2()` | String | undocumented [AAR] |
| `getJsonString()` | String | "Full JSON payload" (rewritten, see §2.6.1) |

**`OwnedProductVo`** (`getOwnedList`) adds:

| Getter | Type | Meaning |
|---|---|---|
| `getPaymentId()` | String | payment ID |
| `getPurchaseId()` | String | purchase transaction ID; this is what consume, acknowledge and server verification take |
| `getPurchaseDate()` | String | "YYYY-MM-DD HH:mm:ss" |
| `getSubscriptionEndDate()` | String | end of the current period (subscriptions) |
| `getPassThroughParam()` | String | deprecated 6.4.0 |
| `getSubscriptionPriceChange()` | `SubscriptionPriceChangeVo` | nullable; parsed from `changeSubscriptionPrices` |
| `getAcknowledgedStatus()` | `AcknowledgedStatus` | from JSON `acknowledgeYN`, default `UNSUPPORTED` |
| `getObfuscatedAccountId()`, `getObfuscatedProfileId()` | String | echoed from the purchase |
| `getJsonString()` | String | |

**`PurchaseVo`** (`startPayment`, `changeSubscriptionPlan`) adds:

| Getter | Type | Meaning |
|---|---|---|
| `getPaymentId()`, `getPurchaseId()`, `getOrderId()` | String | IDs |
| `getPurchaseDate()` | String | |
| `getMinorStatus()` | `MinorStatus` | from JSON `isMinorYN`, default `UNIDENTIFIED` |
| `getItemImageUrl()`, `getItemDownloadUrl()` | String | |
| `getObfuscatedAccountId()`, `getObfuscatedProfileId()` | String | |
| `getJsonString()` | String | |
| `getVerifyUrl()` | String | deprecated since 6.0; use `iap/v6/receipt` |
| `getPassThroughParam()` | String | deprecated 6.4.0 |
| `getUdpSignature()`, `getReserved1()`, `getReserved2()` | String | undocumented [AAR] |

**`SubscriptionPriceChangeVo`:**

| Getter | Type | Meaning |
|---|---|---|
| `getAppName()`, `getItemName()` | String | |
| `getSubscriptionDurationUnit()`, `getSubscriptionDurationMultiplier()` | String | |
| `getStartDate()` | String | when the new price applies |
| `getOriginalLocalPrice()`, `getNewLocalPrice()` | `double` | |
| `getOriginalLocalPriceString()`, `getNewLocalPriceString()` | String | |
| `isConsented()` | `java.lang.Boolean` | whether the user consented |
| `getPriceChangeMode()` | `PriceChangeMode` | |

Consent deep link: `samsungapps://SubscriptionDetail?purchaseId={purchaseId}` [H §SubscriptionPriceChangeVo].

**`ConsumeVo`**; `AcknowledgeVo` extends it with no new members:

| Getter | Type | Meaning |
|---|---|---|
| `getPurchaseId()` | String | |
| `getStatusCode()` | int | 0 success, 1 invalid purchaseId, 2 failed order, 3 invalid product type, 4 already consumed/acknowledged, 5 unauthorized user, 9 unexpected service error [H §ConsumeVo/AcknowledgeVo] |
| `getStatusString()` | String | message |
| `getJsonString()` | String | |

**`PromotionEligibilityVo`:**

| Getter | Type | Meaning |
|---|---|---|
| `getItemId()` | String | |
| `getPricing()` | String | `"FreeTrial"`, `"TieredPrice"` or `"RegularPrice"` [H §PromotionEligibilityVo] |
| `getJsonString()` | String | |

**`ErrorVo`:**

| Getter | Type | Meaning |
|---|---|---|
| `getErrorCode()` | int | response code (§2.8) |
| `getErrorString()` | String | e.g. "Already purchased." |
| `getErrorDetailsString()` | String | e.g. "IS9224/6050/NwCbCAxypi"; the digits before the first `/` are the detail code [H §Response code note] |
| `isShowDialog()` | boolean | whether the SDK showed its error dialog |
| `getExtraString()` | String | undocumented [AAR] |

#### 2.6.1 Date semantics (important for server verification)

- `OwnedProductVo.<init>` reads `mPurchaseDate` and `mSubscriptionEndDate` with `optLong`, formats them with `android.text.format.DateFormat.format("yyyy-MM-dd HH:mm:ss", millis)`, **removes the numeric field from the JSON, and puts the formatted string back**. Only then does it store the JSON as `getJsonString()` [AAR]. `PurchaseVo` does the same for `mPurchaseDate`, and `ProductVo` reads `mShowStartDate`/`mShowEndDate` with `optLong` + `getDateString` [AAR].
- **Inference:** the strings are in the device's default timezone at parse time, with no offset. The raw epoch value is not recoverable on the device, and a DST fall-back hour is ambiguous. **Unverified:** whether `DateFormat.format` emits localized digits in some locales (for example Arabic). Test on a device.
- The server receipt API returns "YYYY-MM-DD HH:mm:ss GMT" [VERIFY §Response]. **Use the server as the source of truth for entitlement windows.**

### 2.7 Enums (`HelperDefine.*`, from [AAR])

| Enum | Values |
|---|---|
| `OperationMode` | `OPERATION_MODE_PRODUCTION`, `OPERATION_MODE_TEST`, `OPERATION_MODE_TEST_FAILURE` (has `getValue()`) |
| `ProrationMode` | `INSTANT_PRORATED_DATE`, `INSTANT_PRORATED_CHARGE` (upgrade only), `INSTANT_NO_PRORATION` (upgrade only), `DEFERRED` ("A downgrade is always executed with this mode") [H §Change subscription plan] [PRORATION] |
| `AcknowledgedStatus` | `UNSUPPORTED` (Galaxy Store too old), `NOT_ACKNOWLEDGED`, `ACKNOWLEDGED` |
| `MinorStatus` | `UNIDENTIFIED`, `NOT_MINOR`, `MINOR` |
| `PriceChangeMode` | `PRICE_INCREASE_USER_AGREEMENT_REQUIRED`, `PRICE_INCREASE_NO_USER_AGREEMENT_REQUIRED`, `PRICE_DECREASE` |
| Product-type strings | `PRODUCT_TYPE_ITEM="item"`, `PRODUCT_TYPE_SUBSCRIPTION="subscription"`, `PRODUCT_TYPE_ALL="all"` |

### 2.8 Response codes

Numeric values come from [AAR] `HelperDefine` constants; meanings from [H §Response code].

| Constant | Code | Meaning / notable detail codes |
|---|---|---|
| `IAP_ERROR_NONE` | 0 | success |
| `IAP_PAYMENT_IS_CANCELED` | 1 | payment canceled (user) |
| `IAP_ERROR_INITIALIZATION` | -1000 | init failure. 10000 IAP client app invalid; 10001 Samsung Checkout app invalid; 10011 service init failed, retry |
| `IAP_ERROR_NEED_APP_UPGRADE` | -1001 | IAP (Galaxy Store) upgrade required |
| `IAP_ERROR_COMMON` | -1002 | catch-all. Plan change: 1005 old sub does not exist, 1006 old sub not subscribed, 1012 not a subscription type, 1014 change already requested. 7002 blocked as a suspicious transaction. TEST_FAILURE: 9000/9005/9013/9014. 9006/9007 passThrough not base64 / too long. 9010 item not consumed yet. 9122 invalid MCC. 9132 invalid token or user ID. 9154 invalid product ID. 9226 null or invalid purchaseID in consume. 9440 device under Honeycomb. 9441 service temporarily unavailable. 9701 certification fail. 100001 unexpected error. 100008 runtime permission disagreed. 100010 TEST mode and user is not a license tester |
| `IAP_ERROR_ALREADY_PURCHASED` | -1003 | 9224: non-consumable re-purchased, or subscription re-purchased before expiry |
| `IAP_ERROR_WHILE_RUNNING` | -1004 | "payment request is made without any information" |
| `IAP_ERROR_PRODUCT_DOES_NOT_EXIST` | -1005 | 9202 not valid in this country/device; 9207 ID not found in the current operation mode |
| `IAP_ERROR_CONFIRM_INBOX` | -1006 | purchase result not received; **the purchase may have completed**, so check `getOwnedList` |
| `IAP_ERROR_ITEM_GROUP_DOES_NOT_EXIST` | -1007 | 9201: no registered products, or IAP not activated in Seller Portal |
| `IAP_ERROR_NETWORK_NOT_AVAILABLE` | -1008 | no network |
| `IAP_ERROR_IOEXCEPTION_ERROR` | -1009 | IOException |
| `IAP_ERROR_SOCKET_TIMEOUT` | -1010 | socket timeout |
| `IAP_ERROR_CONNECT_TIMEOUT` | -1011 | connect timeout |
| `IAP_ERROR_NOT_EXIST_LOCAL_PRICE` | -1012 | 9134: product not for sale in this country |
| `IAP_ERROR_NOT_AVAILABLE_SHOP` | -1013 | 9259: IAP not serviced in this country |
| `IAP_ERROR_NEED_SA_LOGIN` | **-1014** | in the AAR only; not documented [AAR] |
| `IAP_ERROR_INVALID_ACCESS_TOKEN` | **-1015** | documented ("Access token for Samsung account is not valid") but **absent from the 6.5.2 AAR constants** [H] vs [AAR] |

---

## 3. Integration requirements

### 3.1 Gradle (plugin module `samsung_iap_flutter_android/android/build.gradle`)

```groovy
android {
    namespace '<new.package>'
    compileSdk 36
    defaultConfig { minSdkVersion 23 }   // AAR manifest minSdk 23
    compileOptions { sourceCompatibility JavaVersion.VERSION_17; targetCompatibility JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = '17' }
}
dependencies {
    implementation 'com.samsung.developer:iap:6.5.2'                       // [MVN] [META]
    implementation 'org.jetbrains.kotlinx:kotlinx-coroutines-android:<ver>' // required by Pigeon 28 suspend handlers
    testImplementation 'org.jetbrains.kotlin:kotlin-test-junit5'
    testImplementation 'org.jetbrains.kotlinx:kotlinx-coroutines-test:<ver>'
    testImplementation 'org.mockito:mockito-core:5.x'
}
```

- Repository: `mavenCentral()` is already in the template's `allprojects.repositories`. Consuming apps get Maven Central by default in Flutter's Gradle settings. **Inference:** I did not check every app template.
- Use `implementation`, not `api`. **Inference:** apps never need to touch SDK types because the plugin exposes Dart types only.

### 3.2 AndroidManifest

- Required permissions [INTEG §Add permissions] [CL]:
  - `<uses-permission android:name="com.samsung.android.iap.permission.BILLING"/>`
  - `<uses-permission android:name="android.permission.INTERNET"/>`
- **The 6.5.2 AAR manifest declares neither permission** [AAR], so the plugin's `src/main/AndroidManifest.xml` should declare both. Manifest merge then gives them to every app.
- `<queries><package android:name="com.sec.android.app.samsungapps"/></queries>` is **already in the AAR manifest** [AAR]. The release note says SDK ≥ 6.1 does not need a manual entry [RN §Note].
- SDK activities are declared in the AAR [AAR]; nothing to add.

### 3.3 minSdk / targetSdk

- minSdk 23 [INTEG] [RN §6.1.1] [AAR].
- 6.5.0 handles dialog insets for targetSdk ≥ 35 on Android 15+ [RN §6.5.0].
- Flutter 3.47.5 app defaults: compile/target 36, min 24 [FLUTTER-EXT].

### 3.4 ProGuard / R8

- **Not verified.** Any official rules would be in the login-walled integration guide.
- [AAR] ships no `proguard.txt` (no consumer rules). Scanning all classes with `javap` found no reflection (`Class.forName`, `getDeclared*`). VOs are parsed field by field with `org.json`, and the AIDL stubs are ordinary classes.
- **Inference:** R8 should work without rules. Mitigation: add a small `consumer-rules.pro` with `-keep class com.samsung.android.sdk.iap.lib.** { *; }` and `-keep class com.samsung.android.iap.** { *; }` (cheap), and make a release-mode (`--release`, minified) device purchase part of S3 acceptance.

### 3.5 Account, store and portal prerequisites

- **Device:** Samsung phone. Samsung IAP does not work on non-Samsung phones (only on devices paired with a Galaxy Watch) [FAQ Q02]. Galaxy Store installed, a Samsung account signed in, and a payment method registered [FAQ Q05]. A payment method is needed even for sandbox purchases [TG-PREP step 1].
- **Seller:**
  - A commercial seller account is required to sell in-app products [FAQ Q14] [CL §Overview].
  - Register the app (upload an APK/AAB with the BILLING permission) and its products in Seller Portal. New products are inactive until activated [INTEG §To register an app].
  - The app package name must differ from the same app's listing in other stores [INTEG]. **Implication:** each Flutter app needs a `galaxy` flavor with its own `applicationId`, which the app owns, not the plugin.
- **Testers:**
  - License testers are Samsung-account emails in Seller Portal → Profile → License Test, up to 400 [TG-PREP].
  - A Closed Beta Test allows up to 400 license testers and 50,000 beta testers; the app must be *Beta Deployed*, which can take about 20 min [TG-PREP].
  - Tester list changes take 10 min [TG-TESTERS].
  - Open Beta is not supported for IAP [SUBMIT §Set up a beta test].
  - Beta purchase history disappears when the app becomes a regular release [TG-PROD Note].
- **Submission:** the build must use `OPERATION_MODE_PRODUCTION` [SUBMIT] [TG-PROD].

---

## 4. Prior art: Genopets `samsung_galaxy_in_app_purchase`

Repo: https://github.com/Genopets/samsung_galaxy_in_app_purchase. Branch `master`, MIT, 6 stars. Created 2024-05-22, last push 2025-10-20 ("fix: add namespace"). Published on pub.dev as 0.5.0, and the only other Samsung IAP package there (pub.dev search, 2026-09-30) [GENO].

**Coverage:**
- `getProductDetails`, `purchaseItem(productId, passThroughParam)`, `consumePurchasedItem`, `getUserOwnedItems`, `getPlatformVersion`.
- **Missing:** acknowledge, `changeSubscriptionPlan`, promotion eligibility, obfuscated IDs, setShowErrorDialog. The README says "only Consumables were included in this first version" [GENO README].

**SDK version:**
- README says v6.1 [GENO README §How it works].
- It ships a renamed binary, `android/libs/samsung-sdk-iap-genopets-1.0.0.aar` (254 KB), and imports `com.samsung.android.sdk.iap.lib.helper.HelperDefine`. The 6.5.2 class is in `.constants`, so **Inference:** the binary predates 6.5.2's layout.

**Architecture:**
- A single (non-federated) package with a `MethodChannel`.
- Kotlin `GalaxyIapPlugin` (FlutterPlugin only, no ActivityAware) calls `IapHelper.getInstance(applicationContext)` and `setOperationMode(...)` **on every call**.
- Results are sent as `list.map { it.jsonString }.toString()`, a JSON array string that Dart `jsonDecode`s into hand-written entities keyed by `mItemId`, `mPurchaseId` and so on [GENO `GalaxyIapPlugin.kt`, `lib/entities/*`].

**Mistakes to avoid** (each seen in [GENO] source):

1. **Defaults to TEST mode.** Dart `OperationMode operationMode = OperationMode.test` on every method, and the Kotlin `else -> OPERATION_MODE_TEST` fallback. Combined with Samsung's warning that a TEST build breaks purchases for real users [SUBMIT], this default is dangerous.
2. **Futures can hang forever.**
   - `if (errorVo == null) return` and `if (productList == null) return` exit without calling `result`.
   - The `Boolean` returns of `startPayment`/`getOwnedList`/`consumePurchasedItems` are ignored, and §2.3 shows those `false` paths never call back.
3. **Vendored local AAR plus `flatDir`.**
   - The plugin `build.gradle` uses `implementation(name:'samsung-sdk-iap-genopets-1.0.0', ext:'aar')` with `flatDir` commented out.
   - The README tells apps to add `flatDir { dirs project(':samsung_galaxy_in_app_purchase').file('libs') }` to their root Gradle.
   - It also commits an 11.7 MB `android/libs/flutter.jar`.
   - Now unnecessary: Maven Central (§2.1).
4. **Stringly-typed errors.** `result.error(errorVo.errorCode.toString(), errorString, null)`, then Dart rethrows a `PlatformException` with a prefixed message. Error detail strings and `isShowDialog` are dropped.
5. **Type bugs in entities.**
   - `GalaxyProduct.showStartDate` is an `int` read from `json['mShowStartDate']`, but the SDK rewrites that field to a formatted string (§2.6.1). **Inference:** that is a cast error at runtime.
   - Required non-null fields read with `json[...]` crash on absent keys.
   - Field names keep the `m` prefix.
6. **Uses deprecated APIs.** `passThroughParam` (passes `"na"`), and `getIsConsumable()` injected as `isConsumable`.
7. **Weak token check.** `PlatformInterface.verifyToken` with `static const Object _token = Object()`. `plugin_platform_interface` says `verifyToken` "will be deprecated", and `verify` rejects const tokens [PPI source].
8. **Old build config.** `compileSdkVersion 31`, which prompted open issue #4 about requiring compileSdk ≥ 34 [GENO-ISSUE4]. `minSdkVersion 18`, below the SDK's 23.

**Worth keeping:**
- The call flow: getInstance → mode → call.
- The example app idea: a products list, then purchase, then consume.
- The README's step-by-step for Seller Portal and license testers.

---

## 5. Proposed Dart API and types

### 5.1 Futures, not streams

The SDK is one-shot callback per call: each method takes its own listener and gets exactly one result (or none, §2.3) [H: every "Response" section]. There is **no global purchase-updates listener** like Play Billing's `PurchasesUpdatedListener`, which is why `in_app_purchase_android` needs a `@FlutterApi onPurchasesUpdated` [IAPA-MSG]. Samsung's out-of-band recovery is pull-based: `getOwnedList()` at every launch [H] [FAQ Q12]. So each method maps 1:1 to a `Future`. No `@FlutterApi`, no `EventChannel`. **Skipped:** a `purchaseStream`, which would add a second source of truth with no SDK event behind it. Add one only if a future SDK adds push updates.

### 5.2 Package split

- **`samsung_iap_flutter_platform_interface`** owns every public type (models, enums, exception) and `SamsungIapFlutterPlatform`. This follows the federated pattern [FED §Federated plugins].
- **`samsung_iap_flutter_android`** owns Pigeon (`messages.dart`), converts Pigeon `Platform*` classes into the public models (the `in_app_purchase_android` pattern of `Platform*` wire types [IAPA-MSG]), maps `PlatformException` to `SamsungIapException`, and runs the serial call queue.
- **`samsung_iap_flutter`** (app-facing) holds a thin `SamsungIap` class, re-exports the models, and does argument validation, which runs the same on every platform.

### 5.3 App-facing API

```dart
class SamsungIap {
  const SamsungIap();                      // const + instance methods: apps can mock it
  SamsungIapFlutterPlatform get _p => SamsungIapFlutterPlatform.instance;

  /// Must be called once before anything else. Default is PRODUCTION (SDK default [H]).
  Future<void> initialize({OperationMode mode = OperationMode.production, bool showErrorDialog = true});

  /// No dialogs; lets Galaxy builds decide whether to show a store at all.
  Future<GalaxyStoreStatus> getGalaxyStoreStatus();   // available | notInstalled | disabled | invalid

  Future<List<SamsungProduct>> getProducts([List<String> productIds = const []]); // [] = all
  Future<List<OwnedProduct>> getOwnedProducts({OwnedProductFilter filter = OwnedProductFilter.all});
  Future<SamsungPurchase> purchase(String productId, {String? obfuscatedAccountId, String? obfuscatedProfileId});
  Future<List<PurchaseAckResult>> consume(List<String> purchaseIds);
  Future<List<PurchaseAckResult>> acknowledge(List<String> purchaseIds);
  Future<List<PromotionEligibility>> getPromotionEligibility(List<String> subscriptionIds);
  Future<SamsungPurchase> changeSubscriptionPlan({
    required String fromProductId, required String toProductId, required ProrationMode prorationMode,
    String? obfuscatedAccountId, String? obfuscatedProfileId});
}
```

Validation before any call is sent, all throwing `SamsungIapException(kind: invalidArgument)`:
- IDs must be non-empty.
- Obfuscated IDs must be ≤ 64 chars and not email-shaped. This mirrors the SDK check [AAR], which would otherwise just return `false`.
- A profile ID requires an account ID [H] [AAR].
- `consume`/`acknowledge` with an empty list are rejected: the SDK throws "_purchaseIds is null or empty" and returns `false` [AAR].
- Joining lists with `,` happens in Dart.

**Skipped:** top-level functions like the template's `getPlatformName()`. They are harder to fake in app tests.

### 5.4 Models (platform interface)

All models are immutable, with `==`/`hashCode` via a record or manual implementation. Each keeps `rawJson` (`getJsonString()`) for forward compatibility and support logs.

```dart
enum OperationMode { production, test, testFailure }
enum OwnedProductFilter { item, subscription, all }        // "item" | "subscription" | "all"
enum SamsungProductType { item, subscription, unknown }    // mType
enum PeriodUnit { week, month, year }                      // "WEEK" | "MONTH" | "YEAR"
enum AcknowledgedStatus { unsupported, notAcknowledged, acknowledged }
enum MinorStatus { unidentified, notMinor, minor }
enum PriceChangeMode { increaseConsentRequired, increaseNoConsentRequired, decrease }
enum ProrationMode { instantProratedDate, instantProratedCharge, instantNoProration, deferred }
enum PromotionPricing { freeTrial, tieredPrice, regularPrice, unknown }
enum GalaxyStoreStatus { available, notInstalled, disabled, invalid }

class SubscriptionPeriod { final int count; final PeriodUnit unit; }       // from multiplier + unit strings
class IntroductoryOffer {                                                // from tiered* fields when tieredSubscriptionYN == "Y"
  final String? price; final String formattedPrice; final SubscriptionPeriod period; final int cycles; }

class SamsungProduct {
  final String id, name, description, rawJson;
  final SamsungProductType type;
  final double? price; final String formattedPrice, currencyCode, currencySymbol;
  final SubscriptionPeriod? subscriptionPeriod;   // null for items
  final int? freeTrialDays;
  final IntroductoryOffer? introductoryOffer;
  final DateTime? availableFrom, availableUntil;  // showStart/EndDate, local time (§2.6.1)
  final Uri? imageUrl, downloadUrl;
}

class OwnedProduct {
  final String productId, name, purchaseId, paymentId, rawJson;
  final SamsungProductType type;
  final DateTime? purchaseDate, subscriptionEndDate;   // local time, approximate
  final AcknowledgedStatus acknowledgedStatus;
  final SubscriptionPriceChange? priceChange;
  final String? obfuscatedAccountId, obfuscatedProfileId;
  final double? price; final String formattedPrice, currencyCode;
}

class SamsungPurchase {
  final String productId, name, purchaseId, paymentId, orderId, rawJson;
  final SamsungProductType type;
  final DateTime? purchaseDate;
  final MinorStatus minorStatus;
  final String? obfuscatedAccountId, obfuscatedProfileId;
  final double? price; final String formattedPrice, currencyCode;
}

class SubscriptionPriceChange {
  final PriceChangeMode mode; final bool? consented; final DateTime? startDate;
  final double originalPrice, newPrice; final String originalFormattedPrice, newFormattedPrice;
  final SubscriptionPeriod? period;
}
// OwnedProduct also gets: Uri get subscriptionDetailLink => Uri.parse('samsungapps://SubscriptionDetail?purchaseId=$purchaseId'); [H]

enum AckStatus { success, invalidPurchaseId, failedOrder, invalidProductType, alreadyProcessed, unauthorized, serviceError, unknown }
class PurchaseAckResult { final String purchaseId; final AckStatus status; final int statusCode; final String message; }

class PromotionEligibility { final String productId; final PromotionPricing pricing; }
```

Parsing rules, pure Dart and unit-testable:
- `""` → `null` for optional fields (§2.6).
- Unknown enum strings → `unknown`. Never throw on a new server value.
- `DateTime.parse('yyyy-MM-dd HH:mm:ss')` yields a local `DateTime`. Dart's local zone is the device zone, so this matches how the SDK formatted it (**Inference**).
- `"Y"`/`"N"` → `bool`.
- Numeric strings (`tieredSubscriptionCount`, multipliers, `freeTrialPeriod`) → `int.tryParse`.

Deliberately **not exposed:** deprecated `isConsumable`, `passThroughParam`, `verifyUrl`, `reserved1/2`, `udpSignature`, and `setPackageName`. `rawJson` keeps them reachable.

### 5.5 What server-side verification needs from the plugin

- **Receipt check:** `GET https://iap.samsungapps.com/iap/v6/receipt?purchaseID=…`, HTTPS only [VERIFY §Request]. The docs show no auth header.
  - The response includes `status` ∈ `success|fail|cancel`, `mode` ∈ `TEST|PRODUCTION` (**production servers must reject `TEST`**), `itemId`, `paymentId`, `orderId`, `packageName`, `consumeYN`, `acknowledgeYN`, GMT dates, and the obfuscated IDs [VERIFY §Response].
  - So the plugin must expose `purchaseId` (essential), plus `productId`, `orderId`, `paymentId` and the obfuscated IDs, on both `SamsungPurchase` and `OwnedProduct`.
- **Subscriptions:** status (`subscriptionStatus`, `subscriptionEndDate`, `currentPaymentPlan`, and so on) comes from the Galaxy Store Developer API: `GET /iap/seller/v6/applications/<packageName>/purchases/subscriptions/<purchaseId>` with a Bearer token and `service-account-id` [API-SUBS] [API-START].
- **Server-side consume/acknowledge:** `PATCH /iap/v6/applications/<packageName>/purchases/<purchaseId>` with `{"action":"consume"|"acknowledge"}` [API-ACK]. If the backend does this, the app may skip the SDK consume/ack calls. That is a product decision.
- **Push notifications:** Instant Server Notification (ISN) sends server-side events for subscriptions and products [ISN].
- **Plugin stance:** expose IDs; do no networking.

---

## 6. Pigeon schema and Kotlin side

### 6.1 `pigeons/messages.dart` sketch (Pigeon 28.x, `@async` → Kotlin `suspend`)

```dart
@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/messages.g.dart',
  dartPackageName: 'samsung_iap_flutter_android',
  kotlinOut: 'android/src/main/kotlin/<pkg path>/Messages.g.kt',
  kotlinOptions: KotlinOptions(package: '<pkg>'),
  copyrightHeader: 'pigeons/copyright.txt',
))

enum PlatformOperationMode { production, test, testFailure }
enum PlatformProrationMode { instantProratedDate, instantProratedCharge, instantNoProration, deferred }
enum PlatformStoreStatus { available, notInstalled, disabled, invalid }

// Wire types mirror VOs 1:1 as raw strings/doubles; ALL interpretation (dates, "Y"/"N", enums
// from strings, "" → null) happens in Dart where it is unit-testable without Android.
class PlatformProduct {
  PlatformProduct({required this.itemId, /* ... */});
  String itemId; String itemName; double? itemPrice; String itemPriceString;
  String currencyUnit; String currencyCode; String itemDesc; String type;
  String subscriptionDurationUnit; String subscriptionDurationMultiplier;
  String tieredSubscriptionYN; String tieredPrice; String tieredPriceString;
  String tieredSubscriptionDurationUnit; String tieredSubscriptionDurationMultiplier;
  String tieredSubscriptionCount; String showStartDate; String showEndDate;
  String itemImageUrl; String itemDownloadUrl; String freeTrialPeriod; String json;
}
class PlatformPriceChange {
  String appName; String itemName; String durationUnit; String durationMultiplier; String startDate;
  double originalLocalPrice; String originalLocalPriceString; double newLocalPrice; String newLocalPriceString;
  bool? consented; String? priceChangeMode;   // enum .name
}
class PlatformOwnedProduct {
  String itemId; String itemName; double? itemPrice; String itemPriceString; String currencyUnit;
  String currencyCode; String itemDesc; String type; String paymentId; String purchaseId;
  String purchaseDate; String subscriptionEndDate; String acknowledgedStatus; // enum .name
  PlatformPriceChange? priceChange; String obfuscatedAccountId; String obfuscatedProfileId; String json;
}
class PlatformPurchase {
  String itemId; String itemName; double? itemPrice; String itemPriceString; String currencyUnit;
  String currencyCode; String itemDesc; String type; String paymentId; String purchaseId; String orderId;
  String purchaseDate; String minorStatus; String obfuscatedAccountId; String obfuscatedProfileId; String json;
}
class PlatformAckResult { String purchaseId; int statusCode; String statusString; }
class PlatformPromotion { String itemId; String pricing; }

@HostApi()
abstract class SamsungIapHostApi {
  void initialize(PlatformOperationMode mode, bool showErrorDialog);   // sync
  PlatformStoreStatus getStoreStatus();                                // sync, no dialog
  @async List<PlatformProduct> getProductsDetails(String productIds);  // comma-joined in Dart
  @async List<PlatformOwnedProduct> getOwnedList(String productType);
  @async PlatformPurchase startPayment(String itemId, String? obfuscatedAccountId, String? obfuscatedProfileId);
  @async List<PlatformAckResult> consumePurchasedItems(String purchaseIds);
  @async List<PlatformAckResult> acknowledgePurchases(String purchaseIds);
  @async List<PlatformPromotion> getPromotionEligibility(String itemIds);
  @async PlatformPurchase changeSubscriptionPlan(String oldItemId, String newItemId,
      PlatformProrationMode mode, String? obfuscatedAccountId, String? obfuscatedProfileId);
}
```

**Why Java enums cross as `.name` strings:**
- Kotlin does `vo.acknowledgedStatus?.name ?: "UNSUPPORTED"`, and Dart maps the string. Pigeon enums would force the Kotlin side to map every SDK enum value, and an unknown future value would crash that `when`.
- Strings degrade to `unknown` in Dart instead.
- Inputs (mode, proration) do use Pigeon enums, because the plugin controls those.
- Pigeon supports enums and nullable fields [PIGEON §Features].

**Errors:** thrown as `FlutterError(code, message, details)`. Pigeon catches exceptions thrown from `@async` (suspend) methods and turns them into `PlatformException` [PIGEON §Error Handling]. The generated `wrapError` in the repo's `Messages.g.kt` already does this. Codes:

| Pigeon `code` | `details` | When |
|---|---|---|
| `"sdk"` | `[errorCode:int, errorDetailsString, extraString, isShowDialog:bool]` | `ErrorVo.errorCode != 0` |
| `"not_sent"` | `[methodName]` | SDK returned `false` |
| `"store_unavailable"` | `[notInstalled\|disabled\|invalid]` | pre-check failed |
| `"store_update_required"` | – | acknowledge needs Galaxy Store ≥ 4.5.90 [AAR] |
| `"not_initialized"` | – | a call arrived before `initialize` |

**Alternative:** return `Result { data?, error? }` objects, the way `in_app_purchase_android` returns `PlatformBillingResult` [IAPA-MSG]. Not chosen because `FlutterError` needs no schema and tests just as well. Revisit if `details` typing becomes painful.

### 6.2 Kotlin plugin shape

```kotlin
class SamsungIapFlutterPlugin(
    private val helperFactory: (Context) -> IapHelper = IapHelper::getInstance, // test seam; no wrapper interface
) : FlutterPlugin, SamsungIapHostApi {
    private lateinit var context: Context
    private var helper: IapHelper? = null

    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        context = b.applicationContext; SamsungIapHostApi.setUp(b.binaryMessenger, this)
    }
    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        SamsungIapHostApi.setUp(b.binaryMessenger, null)   // IapHelper has no dispose() in 6.5.2 [AAR]
    }
    override fun initialize(mode: PlatformOperationMode, showErrorDialog: Boolean) {
        helper = helperFactory(context).apply { setOperationMode(mode.sdk()); setShowErrorDialog(showErrorDialog) }
    }
    override suspend fun getOwnedList(productType: String) =
        call("getOwnedList") { done -> h().getOwnedList(productType) { e, l -> done(e) { l.orEmpty().map { it.toPlatform() } } } }

    // getProductsDetails returns void and can silently drop the callback → pre-check the store first.
    override suspend fun getProductsDetails(productIds: String): List<PlatformProduct> {
        requireStore()
        return call("getProductsDetails") { done -> h().getProductsDetails(productIds) { e, l -> done(e) { l.orEmpty().map { it.toPlatform() } } }; true }
    }

    /** Bridges one SDK call to one suspend result. Guards against: `false` return (no callback),
     *  double callback, and callback-before-return. */
    private suspend fun <T> call(name: String, start: (done: (ErrorVo?, () -> T) -> Unit) -> Boolean): T =
        suspendCancellableCoroutine { cont ->
            val once = java.util.concurrent.atomic.AtomicBoolean(false)
            val sent = start { err, value ->
                if (!once.compareAndSet(false, true)) return@start
                if (err == null || err.errorCode == IapHelper.IAP_ERROR_NONE) cont.resume(value())
                else cont.resumeWithException(err.toFlutterError())
            }
            if (!sent && once.compareAndSet(false, true)) cont.resumeWithException(FlutterError("not_sent", "$name was not sent (busy or invalid input)", listOf(name)))
        }
}
```

- **Activity binding:** none. §2.3 shows the SDK uses the application context and `FLAG_ACTIVITY_NEW_TASK`. `in_app_purchase_android` implements `ActivityAware` only because Play Billing's `launchBillingFlow` takes an Activity [IAPA-PLUGIN]. **Inference risk:** Android's background-activity-launch limits only bite if a purchase starts while the app is backgrounded, and purchases are user-initiated in the foreground.
- **`requireStore()`:** use `HelperUtil.isInstalledAppsPackage` / `isEnabledAppsPackage` / `isValidAppsPackage` (public statics with no dialog [AAR]). The alternative is plain `PackageManager.getPackageInfo("com.sec.android.app.samsungapps")` for installed/enabled only, which avoids the internal `util` package but skips the signature check. **Decided:** `HelperUtil` (§10.4 #4).
- **Main thread:** Pigeon-28 generated handlers `launch` on `Dispatchers.Main` (see the repo's `Messages.g.kt`). SDK calls therefore start on main, and callbacks arrive on main (**Inference**, §2.3). No thread hopping is needed.
- **Concurrency:**
  - The SDK queues inquiries but refuses payments while anything runs (§2.3). Serialize every call in the **Dart** Android implementation: a `Future` chain, about five lines. A payment then never collides with a launch-time `getOwnedList`.
  - Kotlin still maps a residual `false` to `not_sent`. Multiple Flutter engines in one process share the SDK singleton, and the Dart queue cannot see across engines.
  - `setOperationMode` is process-global, so the last `initialize` wins.
- **Timeouts:** superseded by §10.4 #4b: a fixed 30s timeout on inquiry calls, and none on payment or plan change.
- **VO → Pigeon mapping:** one `toPlatform()` extension per VO. Every getter is null-safe (`?: ""`), because Java `String` returns are platform types in Kotlin.

---

## 7. Error handling strategy

**One exception type with an exhaustive kind enum, plus raw data.**

```dart
enum SamsungIapErrorKind {
  userCanceled, alreadyOwned, productNotFound, notAvailableInCountry, network,
  storeUnavailable, storeUpdateRequired, accountNotSignedIn, purchaseResultUnknown,
  busy, invalidArgument, notInitialized, initializationFailed, general, unknown }

final class SamsungIapException implements Exception {
  final SamsungIapErrorKind kind;
  final int? code;          // raw ErrorVo code (null for plugin-originated)
  final int? detailCode;    // digits before first '/' in errorDetailsString [H], e.g. 9224
  final String message;     // ErrorVo.errorString or plugin message
  final String? details;    // raw errorDetailsString
  final bool dialogShown;   // ErrorVo.isShowDialog(): don't show a second dialog
}
```

**Why an enum, not a sealed class hierarchy:** both give exhaustive `switch` checking. The enum is one class instead of about 14, and every kind carries the same fields. **Decided** (§10.4 #2).

**Mapping**, done in `samsung_iap_flutter_android` from `PlatformException`:

| Source | Kind | App guidance |
|---|---|---|
| code 1 `IAP_PAYMENT_IS_CANCELED` | `userCanceled` | Not an error in UI terms; don't log as failure |
| -1003 (9224) | `alreadyOwned` | Call `getOwnedProducts` and grant or ack |
| -1005 (9202/9207), -1007 (9201) | `productNotFound` | Config problem: product ID, mode, activation, distribution country [H] |
| -1012 (9134), -1013 (9259) | `notAvailableInCountry` | Hide the store UI |
| -1008, -1009, -1010, -1011 | `network` | Retryable |
| -1000 | `initializationFailed` | Retryable (10011 says "Try again") [H] |
| -1001, `store_update_required` | `storeUpdateRequired` | Deep-link to Galaxy Store |
| `store_unavailable` | `storeUnavailable` | Galaxy build on a device without a valid Galaxy Store |
| -1014 (AAR), -1015 (docs) | `accountNotSignedIn` | Prompt Samsung account sign-in |
| -1006 `IAP_ERROR_CONFIRM_INBOX` | `purchaseResultUnknown` | **Must** call `getOwnedProducts` or the server; the purchase may have succeeded [H] |
| `not_sent` | `busy` | Only reachable across engines once the Dart queue exists; retry |
| Dart validation | `invalidArgument` | Programmer error |
| -1002 `IAP_ERROR_COMMON` | `general` | Switch on `detailCode`: 100010 not a license tester, 7002 suspicious transaction, 1005/1006/1012/1014 plan-change problems, 9000–9014 TEST_FAILURE mode |
| -1004 and anything else | `unknown` | Keep `code` for logs |

**Partial failure in consume/ack:** the call-level `ErrorVo` != 0 → throw. Otherwise return a per-item `PurchaseAckResult` list; items can fail individually (status 1–9) even though the call succeeded [H §Notify]. `alreadyProcessed` (4) should count as success for idempotent retry loops (**Inference**).

**SDK dialogs:** `showErrorDialog` defaults to `true` in the SDK [AAR], so Samsung shows its own error UI. Each exception carries `dialogShown` so apps don't show a second message. **Inference:** Flutter apps with their own UI will want `false`. **Decided:** default `true` (§10.4 #3).

---

## 8. Testing strategy

**Dart, runs in CI:**
- `platform_interface`:
  - `instance` setter accepts a subclass that `extends` and rejects one that `implements`. `PlatformInterface.verify` asserts [PPI].
  - Base methods throw `UnimplementedError`.
  - **Model parsing tables:** `""`→null, `"Y"/"N"`, period parsing (`"1"+"MONTH"`), unknown enum → `unknown`, local `DateTime` parsing, malformed numeric strings.
- `android`:
  - Mock the generated `SamsungIapHostApi` with mocktail, as the template's `_MockSamsungIapFlutterApi` already does.
  - Check that each method maps `Platform*` → models.
  - Table-driven `PlatformException` → `SamsungIapErrorKind` over every row in §7, including `detailCode` parsing from `"IS9224/6050/Nw…"`.
  - Serial queue: a second call is not dispatched until the first completes, and a failing call does not block the queue.
  - `registerWith` sets the instance (existing test).
- `app-facing`: mock the platform with `MockPlatformInterfaceMixin` [PPI §Mocking]. Test delegation and argument validation (64-char limit, email regex, profile-requires-account, empty lists).

**Kotlin, runs in CI with a Gradle job:**
- Plain JVM, JUnit 5, Mockito 5 (the inline mock maker is default in Mockito 5, so the non-final `IapHelper` class can be mocked; **Inference** from Mockito 5 defaults), and `kotlinx-coroutines-test` `runTest`.
- Inject `helperFactory = { mockHelper }`.
- Mock the VOs too (they are plain classes) so no Android framework code runs. Constructing real VOs would call `org.json`/`TextUtils`/`DateFormat` from the Android stub jar and fail without Robolectric.
- **Cases:**
  - Listener success → value.
  - `ErrorVo` != 0 → `FlutterError("sdk", details[0] == code)`.
  - `false` return → `not_sent`.
  - Double callback → a single resume.
  - Store pre-check failure → `store_unavailable`, with `getProductsDetails` never invoked.
  - Mode and proration enum mapping.
- **Skipped:** Robolectric. Add it only if real-VO parsing needs coverage; that parsing is Samsung's code.
- **How to run:** Flutter plugin unit tests usually run through the example app's Gradle, e.g. `cd samsung_iap_flutter/example/android && ./gradlew :samsung_iap_flutter_android:testDebugUnitTest` (**Inference:** standard for Flutter plugins; verify the task name once S0 compiles). The existing VGV workflow runs only Dart tests.

**Device, manual or self-hosted; not in CI:**
- Example app plus `integration_test` on a physical Samsung phone with Galaxy Store, signed into a **license tester** account, with an app and products registered in Seller Portal in *Registering/Updating* state [H §Set the IAP operation mode].
- **TEST mode:** list products, buy an item (sandbox popup), check that `getOwnedProducts` includes it, consume, buy again. Buy a subscription and watch the 10-minute renewals [TG-MODES].
- **TEST_FAILURE mode:** every call throws `general` with detailCode 9000/9005/9013/9014, deterministically [H].
- **Error paths:**
  - Cancel the payment sheet → `userCanceled`.
  - Airplane mode → `network`.
  - Tap buy twice / buy during a launch-time `getOwnedList` → queued, no `busy`.
  - A non-tester account in TEST mode → detail 100010.
  - Galaxy Store disabled → `storeUnavailable`.
- A release build with R8 (§3.4).
- A Closed Beta in PRODUCTION mode for the final check [SUBMIT §Beta test].

**Cannot be tested in CI:** anything that touches the real SDK. It needs a Samsung device, Galaxy Store, a signed-in Samsung account with a payment method, and Seller Portal registration [FAQ Q05] [TG-PREP]. Also out of reach: date and timezone behavior on real data, Galaxy Store version gates, and SDK dialogs. Samsung Remote Test Lab is linked from the IAP docs navigation. **Unverified** whether it supports signed-in IAP testing.

---

## 9. Work slices

Each slice ships on its own: all three packages build, tests pass, and the example app runs. Paths are relative to the repo root: `pi/` = `samsung_iap_flutter_platform_interface/`, `and/` = `samsung_iap_flutter_android/`, `app/` = `samsung_iap_flutter/`.

### S0: Foundation (rename, compile, SDK dependency)
- **Scope:** fix the template; add the SDK; no features.
- **Files:**
  - `and/android/build.gradle`: namespace/group, compileSdk 36, minSdk 23, Java 17, dependencies from §3.1.
  - `and/android/src/main/AndroidManifest.xml`: the two permissions.
  - Move `and/android/src/main/kotlin/com/example/verygoodcore/` to the new package path.
  - `and/pigeons/messages.dart`: `KotlinOptions(package:)`, `kotlinOut`, `dartPackageName`.
  - `and/pigeons/copyright.txt`.
  - `and/pubspec.yaml`: `flutter.plugin.platforms.android.package`.
  - Regenerate `and/lib/src/messages.g.dart` + `Messages.g.kt`.
  - Plugin `.kt`: implement `suspend`.
  - `pi/lib/src/method_channel_samsung_iap_flutter.dart` + its test: delete (decision §10).
  - `app/example/android/app/build.gradle.kts`: `namespace`/`applicationId` (must be the package registered in Seller Portal for device tests).
  - Fluttium files: update or delete.
  - Add a Gradle unit-test CI job.
- **Acceptance:** `flutter build apk` in `app/example` succeeds; the three `flutter test` suites pass; `./gradlew :samsung_iap_flutter_android:testDebugUnitTest` runs one trivial test; the merged manifest of the example APK contains `BILLING`, `INTERNET` and the `queries` entry.
- **Tests:** existing Dart tests adapted; one Kotlin smoke test.

### S1: `initialize` + store status + `getProducts`, end to end
- **Scope:**
  - Pigeon `initialize`, `getStoreStatus`, `getProductsDetails`.
  - `PlatformProduct` → `SamsungProduct`.
  - Minimal `SamsungIapException` (kind `unknown`/`storeUnavailable`/`notInitialized` + raw fields).
  - The serial queue.
  - Replace `getPlatformName` everywhere.
- **Files:**
  - `pi/lib/src/models/{product.dart,enums.dart,exception.dart}` and the barrel.
  - `pi/lib/samsung_iap_flutter_platform_interface.dart` (new abstract methods).
  - `and/pigeons/messages.dart`, `and/lib/samsung_iap_flutter_android.dart`, `and/lib/src/{mappers.dart,errors.dart}`, the Kotlin plugin.
  - `app/lib/samsung_iap_flutter.dart` (`SamsungIap` class).
  - Tests in all three packages.
  - Example: list products.
- **Acceptance:** on a Samsung device in TEST mode as a license tester, the example lists Seller Portal products with correct prices and subscription periods. With Galaxy Store disabled, `getStoreStatus()` returns `disabled` and `getProducts` throws `storeUnavailable` instead of hanging.
- **Tests:** parsing tables; error mapping skeleton; Kotlin `call()` helper cases (success, error, `false`, double callback).

### S2: `getOwnedProducts`
- **Scope:** owned list, `AcknowledgedStatus`, `SubscriptionPriceChange`, date parsing.
- **Files:** `pi/lib/src/models/owned_product.dart`, Pigeon additions, mappers, Kotlin, tests, an example "Owned" tab.
- **Acceptance:** after a TEST purchase (made in the Galaxy Store UI, or wait for S3), the item appears with `purchaseId` and `acknowledgedStatus`. The document explicitly notes the date timezone caveat (§2.6.1).
- **Tests:** the price-change consent flag, and an absent `changeSubscriptionPrices` → `null`.

### S3: `purchase`
- **Scope:** `startPayment` with obfuscated IDs and validation; kinds `userCanceled`, `alreadyOwned`, `busy`, `purchaseResultUnknown`.
- **Files:** `pi/lib/src/models/purchase.dart`, app-facing validation, Pigeon, Kotlin, tests.
- **Acceptance:**
  - A TEST-mode purchase returns a `SamsungPurchase` with `purchaseId`/`orderId`.
  - Cancel → `userCanceled`.
  - Tapping buy while `getOwnedProducts` runs does not fail.
  - A release build with R8 purchases successfully.
- **Tests:** validation (64 chars, email, profile-without-account); Kotlin `false` → `not_sent`; Dart queue ordering.

### S4: `consume` + `acknowledge`
- **Scope:** both calls; `PurchaseAckResult`/`AckStatus`; ack pre-check for Galaxy Store ≥ 4.5.90 → `storeUpdateRequired`.
- **Files:** `pi/lib/src/models/ack_result.dart`, Pigeon, Kotlin, tests, example buttons.
- **Acceptance:** consume makes an item repurchasable. Acknowledge flips `acknowledgedStatus` to `acknowledged` in `getOwnedProducts`. A batch with one bogus ID returns a per-item status of 1 while the others succeed.
- **Tests:** per-item status mapping; empty-list rejection.

### S5: Subscription plan change
- **Scope:** `changeSubscriptionPlan` + `ProrationMode`. Subscription product fields already landed in S1/S2.
- **Files:** Pigeon, Kotlin, app-facing, tests, example.
- **Acceptance:**
  - In TEST mode, upgrade tier A → B with `instantProratedDate` and get a new `SamsungPurchase`.
  - A downgrade with an instant mode yields Samsung's error (document the observed detail code).
  - Plan-change detail codes 1005/1006/1012/1014 surface as `general` + `detailCode`.
- **Tests:** enum mapping; argument validation.

### S6: Promotion eligibility
- **Scope:** `getPromotionEligibility` → `PromotionEligibility`.
- **Files:** `pi/lib/src/models/promotion.dart`, Pigeon, Kotlin, tests, example badge "Free trial available".
- **Acceptance:** a fresh tester sees `freeTrial` for a trial subscription; after purchase or re-subscription they see `regularPrice` [TG-SUBS: "the free trial and introductory pricing will not apply again"].
- **Tests:** unknown pricing string → `unknown`.

### S7: Error hardening
- **Scope:** the full §7 table; `detailCode` parsing; the `dialogShown` flag; the TEST_FAILURE device run; doc comments on every kind.
- **Files:** `and/lib/src/errors.dart`, `pi/lib/src/models/exception.dart`, tests.
- **Acceptance:**
  - Each §7 row has a unit test.
  - A TEST_FAILURE device run shows the expected detail code for all four operations.
  - The -1014/-1015 mapping is confirmed on a device signed out of the Samsung account, or recorded as unobservable.
- **Tests:** table-driven.

### S8: Docs, example, publishing
- **Scope:**
  - README per package, covering: setup; prerequisites (§3.5); operation-mode warning; `getOwnedProducts` on every launch; consume vs acknowledge decision; server verification contract (§5.5); Galaxy flavor with a distinct `applicationId`.
  - Example app polish.
  - pana score. S0 removed the template's pana CI jobs, because `path:` dependencies cap the score. Add them back here, after the swap to version constraints.
  - `CHANGELOG`s.
  - Publish in dependency order: platform_interface → android → app-facing. The repo has `PUBLISHING.md`; follow it.
  - Swap `path:` dependencies for version constraints.
- **Acceptance:** pana with no warnings; `flutter pub publish --dry-run` clean for all three.

---

## 10. Decisions (settled 2026-10-01)

These replace the open questions that were here. They were settled with the user in a grilling session on 2026-10-01.

### 10.1 Overall path

Two tracks, done in this order:

1. **Studio Pyro apps use RevenueCat on Galaxy, through a fork of `purchases_flutter`.** The apps are Life in the UK, US Civics, Canadian Citizenship and PoolCard.
2. **This plugin is built and published separately**, for Flutter developers who don't use RevenueCat or who want Samsung IAP directly.

Why the fork comes first: RevenueCat already supports Galaxy Store natively. Only the Flutter wrapper is missing.

- **purchases-android:** Galaxy support (the `purchases-store-galaxy` module) was experimental from 9.24.0 and stable from 10.7.0. 10.7.0 also upgraded it to Samsung IAP SDK 6.5.2 from Maven. [RC-AND-CL] [RC-AND-INSTALL §Other stores]
- **purchases-hybrid-common 19.5.0:** ships a `hybridcommon-store-galaxy` module, and its `configure` accepts a Galaxy store with a `galaxyBillingMode` (PRODUCTION / TEST / ALWAYS_FAIL). Read in its source: `android/hybridcommon/.../common.kt` and `ConfiguringUnitTests.kt`. [RC-HC]
- **purchases_flutter 10.13.2:** pins `common_version = '19.5.0'` (`android/build.gradle`). Its Dart `PurchasesConfiguration` only has `useAmazon`. The one Galaxy change in its changelog is a `Store.galaxy` enum value (9.15.0). [RC-FL] [RC-FL-CL]
- **Inference:** the fork only needs to thread `store = galaxy` and `galaxyBillingMode` through the Dart and Kotlin layers of `purchases_flutter`, and add the hybrid-common Galaxy artifact. It does not need changes in hybrid-common or purchases-android.

Rejected alternative: verifying purchases on our own backend and mirroring them into RevenueCat as granted entitlements (v1 `…/entitlements/{id}/promotional`, v2 `actions/grant_entitlement`). Grants never auto-renew. They are reported as `PROMOTIONAL` / `NON_RENEWING_PURCHASE` and are excluded from active-subscriber and retention charts. Every renewal would have to be re-granted from Samsung server notifications (ISN). [RC-API-V2-CUSTOMER] [RC-CUSTOMER-PROFILE §Granted Entitlements] [RC-AUDIENCES]

### 10.2 RevenueCat fork (track 1)

| Topic | Decision |
|---|---|
| Fork location | `github.com/Studio-Pyro/purchases-flutter` |
| Change | Add a Galaxy option to `PurchasesConfiguration` (`useGalaxy` plus a billing mode), pass it to hybrid-common's `configure`, and add the hybrid-common Galaxy dependency. |
| Consumption | Apps use a `git:` dependency pinned to a tag (e.g. `10.13.2-galaxy.1`), never a branch. |
| Upstream | Open the same change as a PR to `RevenueCat/purchases-flutter`. Drop the fork once RevenueCat ships Galaxy support in Flutter. |
| First app | Life in the UK, tested on the user's Galaxy Tab with license-tester accounts. Then US Civics, Canadian Citizenship and PoolCard. |
| To verify during fork work | That RevenueCat's Galaxy product identifier equals the Samsung item ID. **Inference**, not yet confirmed. |

### 10.3 App-side Galaxy builds

| Topic | Decision |
|---|---|
| Flavor | Add one `galaxy` flavor to the existing `default` dimension, next to `production` and `staging`/`dev`. There is no second "store" dimension. |
| Store selection | Fixed at build time by the flavor; there is no runtime choice between stores. The `production` (Play) flavor is unchanged and keeps RevenueCat on Google Play Billing. The `galaxy` flavor configures RevenueCat with the `galx_` public key and Galaxy enabled. |
| Entry point | `lib/main_galaxy.dart`. Billing mode is TEST when `kDebugMode`, PRODUCTION otherwise. |
| Galaxy Store detection | Only checks that the store is installed and usable, so the app can show a clear error rather than hang. It is not used to choose a store. |
| applicationId | All four apps are already live on Galaxy Store under their Play package names, e.g. `dev.studiopyro.life_in_the_uk_test_trainer`. They **keep these IDs**, and Galaxy users get the update through the existing listings. Changing the package would make it a different Android app, and existing users would get no updates and lose local data. |
| Package-name caution | Samsung's guide says to use a package name "different from the app registered in other app stores", and warns that otherwise "app update malfunctions" and marketing/promotion problems may occur [INTEG §Create a project with a unique package name]. We accept this for the live apps. Mitigation: sign Galaxy builds with a different key from the Play App Signing key, so one store's build can't be installed as an update over the other's. The user still needs to verify which keys are in use. |
| Tip product | `life_in_the_uk_support_tip_v1` (RevenueCat package `one-time`). The app grants "supporter" status when the product appears in `allPurchasedProductIdentifiers`, so the tip is a permanent unlock, not a repeatable consumable (`lib/features/purchases/cubit/purchases_cubit.dart`). On Galaxy: register a normal item with the same ID, because non-consumable registration ended 2026-01-14 [PG], and mark it non-consumable in RevenueCat so it is acknowledged rather than consumed. `_isSupporter` stays unchanged. |
| Accounts | None. RevenueCat users stay anonymous, and purchases are restored through the user's Samsung account. |
| Dependencies | `pubspec.yaml` is shared by all flavors, so both stores' billing SDKs are compiled into both APKs. In Galaxy builds the app only skips RevenueCat's Play configuration. Whether either store's review objects to the unused billing code was **not researched**, and is the app's responsibility. |

### 10.4 Plugin (track 2)

| # | Topic | Decision |
|---|---|---|
| 1 | Names | Kotlin namespace/package `dev.studiopyro.samsung_iap_flutter`. pub.dev packages `samsung_iap_flutter`, `samsung_iap_flutter_android`, `samsung_iap_flutter_platform_interface`. Replace `com.example.verygoodcore` everywhere (§1). |
| 2 | Error model | One `SamsungIapException` with a `kind` enum, plus the raw `code`, `message` and `dialogShown`. Dart 3 `switch` over the enum gives exhaustiveness. |
| 3 | `showErrorDialog` | Defaults to `true`, matching the SDK. Apps that own their UI pass `false`. `dialogShown` prevents double messaging. |
| 4 | Store pre-check | Use the SDK's `HelperUtil.isInstalledAppsPackage` / `isEnabledAppsPackage` / `isValidAppsPackage`. These avoid the dialog side effect and include the signature check. A removed helper breaks the build, so it shows up when the SDK is bumped. The SDK is pinned to exactly `6.5.2`. The plugin never triggers Samsung's install/enable dialog itself; it exposes `storeStatus()`. |
| 4b | Timeouts | A fixed 30s timeout on inquiry calls (`getProducts`, `getOwnedProducts`, promotion eligibility), as a backstop against callbacks that never arrive. There is no timeout on `purchase` or plan change, because users can stay on the payment UI indefinitely and those calls return `false` instead of hanging. Not configurable. |
| 5 | Template leftovers | Delete `MethodChannelSamsungIapFlutter` and the Fluttium example flows. Pigeon and `integration_test` replace them. |
| 6 | Deprecated fields | `isConsumable` and `passThroughParam` are not exposed. `rawJson` carries them. |
| 7 | Consume/acknowledge | Both are in the plugin (S4). The README explains how to choose per product, and also describes the server-side alternative [API-ACK]. |
| 8 | Concurrency | A Dart-side serial queue. Kotlin rejects overlapping calls with a `busy` error. Multi-engine use is not supported. |
| 9 | Subscriptions | In scope, including plan change (S5). The user's apps sell only one-time tips today, but subscriptions must be ready. |
| 10 | Dates | Device-local `DateTime`, documented as approximate. `rawJson` is kept. Samsung's server receipt (GMT) is the source of truth (§2.6.1). |
| 11 | License | MIT, `Copyright (c) 2026 Studio Pyro`. The README states the plugin is unofficial and not affiliated with Samsung. |
| 12 | Publishing | Validate in the example app first, then publish to pub.dev under a verified `studiopyro.dev` publisher, set up before the first publish. |
| 13 | Device testing | The example app borrows Life in the UK's Galaxy package name from `local.properties` (never committed) and runs on the Galaxy Tab in TEST mode. There is no separate Seller Portal registration. |
| 14 | Server verification | README only: the receipt endpoint (§5.5), rejecting `mode=TEST` in production, matching `itemId`/`packageName`, and a `curl` example. No sample Firebase/Supabase function until users ask. |
| 15 | README: RevenueCat users | Explain that Galaxy builds skip RevenueCat's Play configuration and use this plugin, or RevenueCat's own Galaxy support where available. Mention the shared-pubspec caveat from §10.3. |
| 16 | README: package name | Cite Samsung's distinct-package guidance for **new** apps, and the update/signing caveat for apps already live under a shared package. |

### 10.5 RevenueCat sources

- [RC-AND-INSTALL] https://www.revenuecat.com/docs/getting-started/installation/android (§Other stores: Galaxy from 10.7.0; "Support for other hybrid SDKs is coming soon")
- [RC-AND-CL] https://github.com/RevenueCat/purchases-android/blob/main/CHANGELOG.md (Galaxy entries: beta #2903, OTP #3267, SDK 6.5.2 + Maven #3492, @Experimental removed #3494, billing permission #3539)
- [RC-HC] https://github.com/RevenueCat/purchases-hybrid-common (19.5.0; `android/hybridcommon-store-galaxy`, `common.kt`, `ConfiguringUnitTests.kt`)
- [RC-FL] https://github.com/RevenueCat/purchases-flutter (10.13.2; `lib/purchases_flutter.dart` `useAmazon` only; `android/build.gradle` `common_version = '19.5.0'`)
- [RC-FL-CL] https://github.com/RevenueCat/purchases-flutter/blob/main/CHANGELOG.md ("Adds Galaxy to the Store Enum (#1677)")
- [RC-GALAXY-SETUP] https://www.revenuecat.com/docs/platform-resources/galaxy-platform-resources/galaxy-setup-guide (Seller Portal service account with "Publishing & ITEM" and "GSS" scopes)
- [RC-GALAXY-ISN] https://www.revenuecat.com/docs/platform-resources/server-notifications/galaxy-server-notifications
- [RC-API-V2-CUSTOMER] https://www.revenuecat.com/docs/api-v2/customer (grant/revoke entitlement)
- [RC-CUSTOMER-PROFILE] https://www.revenuecat.com/docs/dashboard-and-metrics/customer-profile (§Granted Entitlements)
- [RC-AUDIENCES] https://www.revenuecat.com/docs/dashboard-and-metrics/audiences

---

## 11. Risks and unknowns

- **Login-walled SDK Integration Guide** (§0): possible required ProGuard rules or setup steps are unverified. Mitigation: the R8 release test in S3.
- **Internal behavior can drift.** Queueing, `false`-without-callback and the store-check side effect were read from bytecode, not docs. A 6.5.x patch may change them. Pin `6.5.2` exactly and re-verify when bumping.
- **Docs vs binary mismatches:** -1014 vs -1015; `getProductsDetails` being `void`. The docs agree on `void`, but it means there is no failure signal.
- **Obfuscated ID limits:** docs say "bytes", the SDK checks chars. The Dart validator should use UTF-8 byte length ≤ 64, the stricter of the two.
- **Local-time date strings:** DST ambiguity, and possibly localized digits (§2.6.1).
- **Debug `BUILD_TYPE` in the shipped AAR:** possibly verbose logs in production (**Inference**).
- **Background activity launch:** the SDK starts activities from the application context. Fine in the foreground; unverified on Android 15+ edge cases such as foldables or multi-window.
- **Process death mid-purchase:** the listener is lost, so apps must reconcile with `getOwnedProducts` at launch [FAQ Q12]. Document this prominently.
- **Test logistics:** license testers, Closed Beta and a *Registering/Updating* app status all involve waits (10–20 min) [TG-PREP] [TG-TESTERS]. Budget time for S1–S6 device acceptance.
- **Non-consumable registration ended 2026-01-14** [PG]. Existing products of that type may still exist and behave differently in `getIsConsumable`. Not tested.

---

## 12. Sources

Samsung (official):
- [PG] Programming Guide: https://developer.samsung.com/iap/programming-guide.html
- [H] IAP SDK Programming (IapHelper API, VOs, response codes): https://developer.samsung.com/iap/programming-guide/iap-helper-programming.html
- [INTEG] Integrate the IAP SDK into Your App: https://developer.samsung.com/iap/programming-guide/integrate-iap-helper-into-your-app.html
- [FLOW] IAP Configuration and In-App Product Processing: https://developer.samsung.com/iap/programming-guide/iap-configuration-and-in-app-item-processing.html
- [VERIFY] Verify a purchase (iap/v6/receipt): https://developer.samsung.com/iap/programming-guide/samsung-iap-server-api.html
- [SUBMIT] Submit the App to Galaxy Store: https://developer.samsung.com/iap/programming-guide/submit-the-app-to-galaxy-store.html
- [RN] Release Note: https://developer.samsung.com/iap/release-note.html?lang=en
- [CL] Code Lab, Add Samsung In-App Purchase service to your app: https://developer.samsung.com/codelab/iap/in-app-purchase.html
- [TG-OV] Test Guide overview: https://developer.samsung.com/iap/test-guide/overview.html
- [TG-MODES] IAP Operation Modes: https://developer.samsung.com/iap/test-guide/iap-operation-modes.html
- [TG-PREP] Prepare to Test: https://developer.samsung.com/iap/test-guide/prepare-to-test.html
- [TG-TESTERS] Tester Types: https://developer.samsung.com/iap/test-guide/tester-types.html
- [TG-SUBS] Test Subscriptions: https://developer.samsung.com/iap/test-guide/test-subscriptions.html
- [TG-PROD] Prepare for Production: https://developer.samsung.com/iap/test-guide/prepare-for-production.html
- [SUB-PLAN] Manage Subscription Plan Changes: https://developer.samsung.com/iap/subscription-guide/manage-subscription-plan/overview.html
- [PRORATION] Proration Modes: https://developer.samsung.com/iap/subscription-guide/manage-subscription-plan/proration-modes.html
- [SUB-MANAGE] Manage Subscriptions: https://developer.samsung.com/iap/subscription-guide/manage-subscriptions.html
- [FAQ] https://developer.samsung.com/iap/faq.html
- [API-START] Get Started with the IAP APIs: https://developer.samsung.com/iap/api/get-started.html
- [API-ACK] Purchase Acknowledgment API: https://developer.samsung.com/iap/api/iap-purchase-acknowledgment.html
- [API-SUBS] Subscription API: https://developer.samsung.com/iap/api/iap-subscription-api.html
- [API-ORDERS] Orders API: https://developer.samsung.com/iap/api/iap-orders-api.html
- [ISN] Instant Server Notification: https://developer.samsung.com/iap/isn/overview.html
- Not accessible (login): https://developer.samsung.com/iap/sdk-integration/overview.html, https://developer.samsung.com/iap/sdk-integration/usage.html
- [META] Samsung/iap-metadata (README, LICENSE, pom): https://github.com/Samsung/iap-metadata
- [MVN] Maven Central artifact: https://repo1.maven.org/maven2/com/samsung/developer/iap/6.5.2/ (`iap-6.5.2.pom`, `iap-6.5.2.aar`, `maven-metadata.xml`)
- [AAR] My `javap -c -p -constants` inspection of `iap-6.5.2.aar` → `classes.jar`, plus `AndroidManifest.xml` and `aar-metadata.properties`. Classes cited: `helper.IapHelper`, `helper.HelperListenerManager`, `constants.HelperDefine(+$*)`, `constants.HelperConstants`, `util.HelperUtil`, `util.InProgressHandler`, `service.ServiceScheduler`, `service.ServiceBinder`, `service.BaseService`, `task.BaseTask`, `vo.*`, `listener.*`, `activity.*`, `BuildConfig`.

Prior art:
- [GENO] https://github.com/Genopets/samsung_galaxy_in_app_purchase (branch `master`: `android/build.gradle`, `android/src/main/kotlin/.../GalaxyIapPlugin.kt`, `lib/*.dart`, `lib/entities/*.dart`, `README.md`, `pubspec.yaml`); pub.dev `samsung_galaxy_in_app_purchase` 0.5.0
- [GENO-ISSUE4] https://github.com/Genopets/samsung_galaxy_in_app_purchase/issues/4

Flutter:
- [FED] Developing packages & plugins, Federated plugins: https://docs.flutter.dev/packages-and-plugins/developing-packages#federated-plugins
- [PPI] plugin_platform_interface 2.1.8 (README "Mocking or faking platform interfaces"; `lib/plugin_platform_interface.dart` `verify` vs `verifyToken`): https://pub.dev/packages/plugin_platform_interface
- [PIGEON] Pigeon README (Features, Synchronous and Asynchronous methods, Error Handling, Task Queue): https://github.com/flutter/packages/blob/main/packages/pigeon/README.md
- [PIGEON-CL] Pigeon CHANGELOG 28.0.0 (`@async` → `suspend`; `@asyncCallback`): https://github.com/flutter/packages/blob/main/packages/pigeon/CHANGELOG.md
- [IAPA-MSG] in_app_purchase_android Pigeon schema: https://github.com/flutter/packages/blob/main/packages/in_app_purchase/in_app_purchase_android/pigeons/messages.dart
- [IAPA-PLUGIN] in_app_purchase_android `InAppPurchasePlugin.java` (`implements FlutterPlugin, ActivityAware`): https://github.com/flutter/packages/blob/main/packages/in_app_purchase/in_app_purchase_android/android/src/main/java/io/flutter/plugins/inapppurchase/InAppPurchasePlugin.java
- [FLUTTER-EXT] Flutter 3.47.5 `packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt` (compileSdk 36, minSdk 24, targetSdk 36): https://github.com/flutter/flutter/blob/stable/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt

Repo files read (starting point): `samsung_iap_flutter_android/{pubspec.yaml,pigeons/messages.dart,lib/**,android/build.gradle,android/settings.gradle.kts,android/src/main/**,test/**}`, `samsung_iap_flutter_platform_interface/{pubspec.yaml,lib/**}`, `samsung_iap_flutter/{pubspec.yaml,lib/**,example/android/app/build.gradle.kts,example/android/app/src/main/AndroidManifest.xml}`, `.github/workflows/samsung_iap_flutter_android.yaml`.
