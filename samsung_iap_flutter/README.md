# samsung_iap_flutter

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

A Flutter plugin for Samsung In-App Purchase (IAP) on Galaxy Store. It wraps Samsung IAP SDK 6.5.2
in a small `Future`-based API with typed models and one exception type. Every call returns or throws,
including the calls where the SDK itself never calls back.

This plugin is unofficial. Studio Pyro maintains it, and it is not affiliated with or endorsed by
Samsung. Report problems in the [issue tracker][issues_link], not to Samsung.

The plugin covers:

- Products and the products a user owns.
- Purchases of one-time items, with consume or acknowledge.
- Subscriptions, plan changes and promotion eligibility.
- The production, test and test-failure operation modes.

Contents:

- [Requirements](#requirements)
- [Set up Seller Portal](#set-up-seller-portal)
- [Install the plugin](#install-the-plugin)
- [Add a Galaxy build flavor](#add-a-galaxy-build-flavor)
- [Quick start](#quick-start)
- [Reconcile at every launch](#reconcile-at-every-launch)
- [Buy a product](#buy-a-product)
- [Consume or acknowledge a purchase](#consume-or-acknowledge-a-purchase)
- [Sell subscriptions](#sell-subscriptions)
- [Check promotion eligibility](#check-promotion-eligibility)
- [Handle errors](#handle-errors)
- [Verify purchases on your server](#verify-purchases-on-your-server)
- [Use with RevenueCat](#use-with-revenuecat)
- [Test your integration](#test-your-integration)
- [Limitations](#limitations)

## Requirements

- Android only. Samsung IAP has no SDK for other platforms. On iOS, web and desktop, every method
  throws `UnimplementedError`, so call the plugin only from your Galaxy build.
- `minSdk` 23 or higher, which Samsung IAP SDK 6.5.2 requires. Flutter's default `minSdk` is
  already higher.
- A Samsung phone or tablet with Galaxy Store, a signed-in Samsung account and a registered payment
  method. The payment method is required even for test purchases. Samsung IAP does not work on an
  emulator or on other phones.

The plugin depends on Samsung IAP SDK 6.5.2 from Maven Central (`com.samsung.developer:iap:6.5.2`).
You do not download the SDK yourself.

## Set up Seller Portal

Samsung sells in-app products only for apps registered in [Seller Portal][seller_portal_link]. Do
these steps before your first test purchase:

1. Get a commercial seller account. A free account cannot sell in-app products.
2. Register the app. Upload a build that has the Samsung billing permission. The plugin adds the
   permission to your app.
3. Register the items and subscriptions. A new product is inactive until you activate it.
4. Add license testers in **Profile > License Test**. A license tester is the email address of a
   Samsung account. You can add up to 400. A change to the list takes 10 minutes to apply.

Pick an operation mode for each build and pass it to `initialize`:

| Mode | What happens | Use it for |
|---|---|---|
| `OperationMode.production` | Real payments and real results. The default. | Every build you submit for review or release. |
| `OperationMode.test` | Payments succeed and charge nothing. Only license testers can buy. Everyone else gets `general` with detail code 100010. | Development, while the app status in Seller Portal is *Registering* or *Updating*. |
| `OperationMode.testFailure` | Every Samsung call fails. | Testing your error handling. See [Test error handling](#test-error-handling). |

A purchase made in one mode is owned only in that mode. Samsung tells you to use the test modes only
while the app status is *Registering* or *Updating*. If you submit a build in TEST mode, license
testers get products for free and everyone else gets an error.

In TEST mode, Samsung changes these timings:

- Each subscription period lasts 10 minutes, and so does the grace period.
- A subscription cancels itself after 12 renewals.
- After you acknowledge an item, the same tester can buy it again after 10 minutes.

To test PRODUCTION mode before release, use a Closed Beta. License testers who install the app from
the beta link are not charged. A Closed Beta takes up to 400 license testers and 50,000 beta
testers, and the app must be *Beta Deployed*, which takes about 20 minutes. Samsung does not support
in-app purchases in an Open Beta. Purchases made in a beta disappear when the app becomes a regular
release.

For the full process, see Samsung's [Prepare to test][test_prep_link] and
[IAP operation modes][test_modes_link] guides.

## Install the plugin

```sh
flutter pub add samsung_iap_flutter
```

You change no Gradle files and no manifest. The plugin adds the SDK, the billing and internet
permissions, and an R8 keep rule for Samsung's IAP service (AIDL) classes.

## Add a Galaxy build flavor

An app that is also on Google Play needs a separate build for Galaxy Store. Add an Android product
flavor for it, so each store gets the billing code it expects.

### Use a distinct package name for a new app

Samsung's [integration guide][integrate_link] asks for a package name that differs from the app's
listing in other stores. It warns that a shared name can break app updates and Samsung's marketing
promotions. For an app that is not live on Galaxy Store yet, give the Galaxy flavor its own
`applicationId`. In `android/app/build.gradle.kts`:

```kotlin
android {
    flavorDimensions += "store"
    productFlavors {
        create("play") {
            dimension = "store"
        }
        create("galaxy") {
            dimension = "store"
            applicationIdSuffix = ".galaxy"
        }
    }
}
```

Give each flavor its own entry point, and initialize this plugin only in `lib/main_galaxy.dart`.
Build and run the Galaxy flavor:

```sh
flutter run --flavor galaxy -t lib/main_galaxy.dart
flutter build apk --flavor galaxy -t lib/main_galaxy.dart
```

Register the Galaxy package name in Seller Portal. If you have a backend, have it check that each
receipt's `packageName` is the Galaxy package name. See
[Verify purchases on your server](#verify-purchases-on-your-server).

### Keep the package name of an app that is already live

If the app is already on Galaxy Store under the same package name as on Google Play, keep that
name. A new package name makes a different Android app. Existing users would get no updates, and
they would lose the app's local data.

The risk of a shared package name is that one store's build can install as an update over the other
store's build. Android installs an update only when it has the same signing key as the installed
app. Sign the Galaxy build with a different key from the one Google Play signs with, and neither
store's build can replace the other. If you use Play App Signing, Google signs the Play build with
its own key, so check which key each store's build has. With different keys, a user who wants to
move between stores must uninstall the app first.

## Quick start

Check Galaxy Store, initialize, reconcile what the user owns, and load the products:

```dart
import 'package:flutter/foundation.dart';
import 'package:samsung_iap_flutter/samsung_iap_flutter.dart';

Future<List<SamsungProduct>> startStore(SamsungIap iap) async {
  if (await iap.getGalaxyStoreStatus() != GalaxyStoreStatus.available) {
    return []; // Hide the store UI.
  }
  await iap.initialize(
    mode: kReleaseMode ? OperationMode.production : OperationMode.test,
  );
  await reconcile(iap, await iap.getOwnedProducts());
  return iap.getProducts(['coins_100', 'premium', 'monthly']);
}
```

`getGalaxyStoreStatus` shows no dialog and works before `initialize`. Call `initialize` once,
before any other method. Its `mode` defaults to `OperationMode.production`, so a build that forgets
to set it never ships in TEST mode. `getProducts` with no IDs returns every product of the app.

Create the client once, with `const iap = SamsungIap();`, and pass it to the code that uses it, as
`startStore` takes it. In tests, pass a mock in place of `iap`. See
[Test your integration](#test-your-integration). The rest of this guide calls the client `iap`.

## Reconcile at every launch

The plugin has no purchase stream. A purchase reaches the app only as the result of `purchase`. If
the app process dies while the payment sheet is open, that result is lost, but the user has still
paid. Call `getOwnedProducts` at every launch and grant anything you have not granted yet:

```dart
Future<void> reconcile(SamsungIap iap, List<OwnedProduct> owned) async {
  for (final product in owned) {
    await grant(product.productId, product.purchaseId); // Skip it if already granted.
  }
  final repeatable = [
    for (final product in owned)
      if (isRepeatable(product.productId)) product.purchaseId,
  ];
  final permanent = [
    for (final product in owned)
      if (!isRepeatable(product.productId) &&
          product.acknowledgedStatus == AcknowledgedStatus.notAcknowledged)
        product.purchaseId,
  ];
  if (repeatable.isNotEmpty) await iap.consume(repeatable);
  if (permanent.isNotEmpty) await iap.acknowledge(permanent);
}
```

`grant` and `isRepeatable` are your own code. An item you have not consumed stays in the owned list,
so `reconcile` also finishes any consume that failed last time.

You can call `purchase` while `getOwnedProducts` is still running. The plugin runs one Samsung call
at a time, and the purchase starts when the inquiry finishes.

## Buy a product

Call `purchase` with a product ID from Seller Portal, as in the example under
[Handle errors](#handle-errors). Samsung shows its payment sheet, and the `Future` completes when
the user leaves it. There is no timeout.

```dart
final purchase = await iap.purchase('coins_100', obfuscatedAccountId: hashedUserId);
```

Verify, then grant. If you have a server, send it `purchase.purchaseId` and let it verify the
purchase before you grant access. See
[Verify purchases on your server](#verify-purchases-on-your-server). After you grant the
purchase, consume or acknowledge it.

### Pass obfuscated IDs

Pass `obfuscatedAccountId`, and optionally `obfuscatedProfileId`, so your server can match a
purchase to a user. Samsung returns them on the purchase and on each owned product. The plugin
rejects these values with `invalidArgument` before it calls Samsung:

- An ID longer than 64 bytes in UTF-8. Multi-byte characters count as more than one byte.
- An ID that looks like an email address. Pass a hash of your own user ID, not personal data.
- An empty ID. Pass `null` to omit it.
- A profile ID without an account ID.

## Consume or acknowledge a purchase

After you grant a purchase, tell Samsung it is done. Pick the call by what the product is:

- **Consume repeatable items**, such as coins or credits. Until you consume a purchase, buying the
  item again fails with `alreadyOwned`.
- **Acknowledge permanent unlocks and subscriptions.** `acknowledge` marks the purchase as handled
  and keeps it owned. `OwnedProduct.acknowledgedStatus` then reads `acknowledged`.

Samsung registers both kinds as the same item type in Seller Portal, so the choice is yours, per
product. Samsung asks you to send the purchase IDs of one batch in a single call.

```dart
final results = await iap.consume([purchase.purchaseId]);
for (final result in results) {
  if (!result.isProcessed) log('${result.purchaseId}: ${result.status}');
}
```

A batch can partly fail. The call returns one `PurchaseAckResult` per purchase, and each one has
its own `status`. The call throws a `SamsungIapException` only when the whole call fails, for
example when Galaxy Store is not usable.

Handle each purchase by its `status`:

- **Treat `alreadyProcessed` as done.** `isProcessed` is `true` for `success` and for
  `alreadyProcessed`, which means an earlier call already consumed or acknowledged the purchase.
- **Retry `serviceError`.** Send that purchase again in a later call.
- **Do not retry the other statuses.** `invalidPurchaseId`, `failedOrder`, `invalidProductType`
  and `unauthorized` describe the purchase, not the connection. `unknown` is a status this
  version of the plugin does not know. Log them with `statusCode` and `message`.

Handle a failed call as [Handle errors](#handle-errors) describes. Two cases are specific to
these calls:

- **Check the IDs on `general` with `detailCode` 9226.** Samsung rejected a purchase ID and
  failed the whole call instead of that one purchase. Send only purchase IDs from
  `getOwnedProducts`, or split the batch to find the bad ID. A retry of the good IDs is safe,
  because a purchase that an earlier call handled reports `alreadyProcessed`.
- **Update Galaxy Store for `storeUpdateRequired`.** `acknowledge` needs Galaxy Store 4.5.90 or
  later. On an older version, it throws `storeUpdateRequired` before it calls Samsung.

The plugin rejects these arguments with `invalidArgument` before it calls Samsung:

- An empty list.
- An empty ID, or an ID that contains a comma.

### Consume or acknowledge on your server

If your backend verifies purchases, it can also consume or acknowledge them, and the app then does
not call `consume` or `acknowledge`. Send the purchase ID from the app to your server. The server
verifies it with Samsung's receipt API, and then calls the Galaxy Store Developer API:

```http
PATCH https://devapi.samsungapps.com/iap/v6/applications/<packageName>/purchases/<purchaseId>
Authorization: Bearer <access token>
service-account-id: <service account ID>
Content-Type: application/json

{"action": "consume"}
```

Send `{"action": "acknowledge"}` to acknowledge. The response has a `statusCode` per purchase, with
the same codes as `PurchaseAckResult.statusCode`. With this approach, the server that grants a
purchase also consumes it. See Samsung's [Purchase Acknowledgment API][ack_api_link] for the batch
form, and [Get Started with the IAP APIs][iap_api_link] for the access token.

## Sell subscriptions

Sell a subscription with `purchase`, and acknowledge it after you grant it, like a permanent unlock.
While the subscription is active, `getOwnedProducts` returns it, so your launch reconcile sees it.

`OwnedProduct.subscriptionEndDate` is device-local and approximate. Do not build expiry logic on
it. A server reads the subscription status from Samsung's [Subscription API][subs_api_link].

When a subscription has a scheduled price change, `OwnedProduct.priceChange` describes it. If its
`mode` is `PriceChangeMode.increaseConsentRequired` and `consented` is `false`, the user must agree
to the new price in Galaxy Store to keep the subscription. Open
`OwnedProduct.subscriptionDetailLink` to take them there. Open it with an API that takes a string,
such as url_launcher's `launchUrlString`, because `Uri` changes the case of the link.

### Change a subscription plan

Call `changeSubscriptionPlan` to move a subscriber between two tiers of the same subscription.
Samsung shows its payment UI, and the `Future` completes when the user leaves it. There is no
timeout. On success, it returns the `SamsungPurchase` of the new tier. Verify and acknowledge it
like any other purchase. With `deferred`, the new tier starts at the next renewal. Keep granting the
old tier until `getOwnedProducts` or your server receipt shows the new one.

```dart
final purchase = await iap.changeSubscriptionPlan(
  fromProductId: 'monthly',
  toProductId: 'monthly_premium',
  prorationMode: ProrationMode.instantProratedDate,
  obfuscatedAccountId: hashedUserId,
);
```

Pick the proration mode by the direction of the change. Samsung calls a change to a tier that
costs the same or more an upgrade, and a change to a cheaper tier a downgrade.

| Mode | When the new tier starts | How Samsung bills | Use for |
|---|---|---|---|
| `instantProratedDate` | Now | The value left on the old tier becomes time on the new one, so the renewal date moves. | Upgrades. See below for downgrades. |
| `instantProratedCharge` | Now | Charges the price difference for the rest of the period. The renewal date stays. | Upgrades only |
| `instantNoProration` | Now | Charges the new price from the next renewal. | Upgrades only |
| `deferred` | At the next renewal | Charges the new price at renewal. The user cannot change plans again until then. | Downgrades |

Samsung's guides disagree on downgrades. The IAP Helper guide says a downgrade always runs as
`deferred`. The [proration modes][proration_link] page describes an instant downgrade with
`instantProratedDate`. `deferred` is the only mode both guides allow for a downgrade, so pass it for
every downgrade. What Samsung does with an instant downgrade is still to be checked on a device.

Handle the errors as [Handle errors](#handle-errors) describes. After `network` or
`purchaseResultUnknown`, check which tier `getOwnedProducts` reports before you retry.

Samsung reports a change it rejects as `general`, and `detailCode` tells why:

- 1005: the subscription `fromProductId` does not exist.
- 1006: the user is not subscribed to `fromProductId`.
- 1012: `toProductId` is not a subscription.
- 1014: a change was already requested.

The plugin rejects these arguments with `invalidArgument` before it calls Samsung:

- An empty `fromProductId` or `toProductId`.
- An obfuscated ID that breaks the [rules above](#pass-obfuscated-ids).

Samsung's docs describe a change to another tier, but neither they nor the SDK reject the same
tier. The plugin passes such a change on and reports Samsung's answer.

## Check promotion eligibility

A subscription can start with a free trial, an introductory price, or both. Call
`getPromotionEligibility` with the subscription IDs before you show a paywall, and advertise an
offer only when Samsung reports it for that user.

```dart
final eligibility = await iap.getPromotionEligibility(['monthly', 'yearly']);
for (final e in eligibility) {
  final badge = switch (e.pricing) {
    PromotionPricing.freeTrial => 'Free trial',
    PromotionPricing.tieredPrice => 'Intro price',
    PromotionPricing.regularPrice || PromotionPricing.unknown => null,
  };
  // Show badge next to the product with ID e.productId.
}
```

Each `PromotionEligibility` has the `productId` and one `pricing`:

| `pricing` | The user would get | Where to read the details |
|---|---|---|
| `freeTrial` | The free trial | `SamsungProduct.freeTrialDays` |
| `tieredPrice` | The introductory price | `SamsungProduct.introductoryOffer` |
| `regularPrice` | The regular price, with no offer | `SamsungProduct.formattedPrice` |
| `unknown` | A value this plugin version does not know | `PromotionEligibility.rawJson` |

Match the results to your products by `productId`, because their order is not guaranteed. For a
subscription with both a free trial and an introductory price, Samsung is expected to report
`freeTrial`.

Samsung's [Test subscriptions][test_subs_link] guide says a free trial or introductory price does
not apply again when the same tester buys the same subscription again. Expect the same for other
users. After a purchase, and after a re-subscription, `getPromotionEligibility` is expected to report
`regularPrice` for that subscription. A device run has not confirmed either expectation yet. To
test an offer
again, use a different tester, or register a new subscription in Seller Portal.

`getPromotionEligibility` waits up to 30 seconds for Samsung, then throws `network`.
It throws `storeUnavailable` when Galaxy Store is not usable. The plugin rejects these arguments with
`invalidArgument` before it calls Samsung:

- An empty list.
- An empty ID, or an ID that contains a comma.

## Handle errors

Every call throws one type, `SamsungIapException`. Switch over its `kind`. The switch is
exhaustive, so a kind added in a later version is a compile error instead of a silent fallthrough.

```dart
try {
  final purchase = await iap.purchase(
    'coins_100',
    obfuscatedAccountId: hashedUserId,
  );
  // Verify purchase.purchaseId on your server, then grant access.
} on SamsungIapException catch (e) {
  switch (e.kind) {
    case SamsungIapErrorKind.userCanceled:
      return; // The user closed the sheet. Show nothing.
    case SamsungIapErrorKind.alreadyOwned ||
        SamsungIapErrorKind.purchaseResultUnknown ||
        SamsungIapErrorKind.network:
      // The user may own the product now. Check before anything else.
      await reconcile(iap, await iap.getOwnedProducts());
    case SamsungIapErrorKind.busy:
      if (!e.dialogShown) showRetry(); // Stop offering it after a few tries.
    case SamsungIapErrorKind.initializationFailed:
      // Retry only 10011. 10000 and 10001 mean an invalid Samsung app.
      if (e.detailCode != 10011) {
        hideStore();
      } else if (!e.dialogShown) {
        showRetry();
      }
    case SamsungIapErrorKind.accountNotSignedIn:
      if (!e.dialogShown) showSignInPrompt();
    case SamsungIapErrorKind.storeUpdateRequired:
      if (!e.dialogShown) openGalaxyStore();
    case SamsungIapErrorKind.notAvailableInCountry ||
        SamsungIapErrorKind.storeUnavailable:
      hideStore();
    case SamsungIapErrorKind.productNotFound ||
        SamsungIapErrorKind.invalidArgument ||
        SamsungIapErrorKind.notInitialized ||
        SamsungIapErrorKind.general ||
        SamsungIapErrorKind.unknown:
      log('$e ${e.details}'); // Kind, code, detail code and message.
      if (!e.dialogShown) showError();
  }
}
```

With `showErrorDialog: true`, the default of `initialize`, Samsung shows its own dialog for many
errors and sets `dialogShown`. Show your own message only when `dialogShown` is `false`.

Samsung reports a server error in one of two shapes. `purchase` and `changeSubscriptionPlan` return
a negative code, such as -1005, and put the server's detail code in `details`, such as
`IS9207/6050/...`. The other calls can return the server's code itself, such as 9201, with no
details. For such a raw server code, `detailCode` is the code, and `code` keeps the number Samsung
sent. The plugin maps a raw server code like -1002 with that detail code. So -1002 with
`IS9201/...`, -1007 with `IS9201/...` and a plain 9201 all become `productNotFound` with
`detailCode` 9201.

| Kind | Source | What the app does |
|---|---|---|
| `userCanceled` | Samsung code 1 | Nothing. The user closed the sheet. Do not log it as a failure. |
| `alreadyOwned` | -1003, or -1002 or a raw server code with detail code 9224 | Call `getOwnedProducts`, grant what it returns, and consume or acknowledge it. |
| `productNotFound` | -1005, -1007, or -1002 or a raw server code with detail code 9201, 9202 or 9207 | Fix the setup. Check the product ID, the operation mode, the Seller Portal settings and the distribution countries. |
| `notAvailableInCountry` | -1012, -1013, or -1002 or a raw server code with detail code 9134 or 9259 | Hide the store UI for this user. |
| `network` | -1008 to -1011, or no answer within 30 seconds | After `purchase` or `changeSubscriptionPlan`, reconcile first, because the user may have paid. Retry only if the user does not own the product. After any other call, retry. |
| `storeUnavailable` | The plugin, before it calls Samsung | Hide the store UI, or ask the user to install or enable Galaxy Store. `details` names the store status. |
| `storeUpdateRequired` | -1001, or `acknowledge` on Galaxy Store older than 4.5.90 | Send the user to Galaxy Store to update it, then retry. |
| `accountNotSignedIn` | -1014 or -1015 | Ask the user to sign in to a Samsung account, then retry. |
| `purchaseResultUnknown` | -1006, or no purchase in Samsung's answer | Reconcile with `getOwnedProducts` before you tell the user anything. The user may have paid. |
| `busy` | Samsung refused to start the call, for example while it finishes one that timed out | Retry a few times with a growing delay. Samsung showed no UI, so it charged nothing. Samsung also refuses some invalid input this way, so stop if `busy` persists. |
| `invalidArgument` | The plugin, before it calls Samsung | Fix the call. Each method's docs list its rules. |
| `notInitialized` | The plugin | Call `initialize` first. |
| `initializationFailed` | -1000 | With `detailCode` 10011, retry a few times with a growing delay. With 10000, the IAP client app is invalid, and with 10001, the Samsung Checkout app is invalid. Do not retry those two. Hide the store UI. |
| `general` | -1002 or a raw server code with any other detail code | Read `detailCode`. See below. |
| `unknown` | -1004 and any other negative code | Log `code` and `message`. |

`network` after `consume` or `acknowledge` is safe to retry, even if the first call reached Samsung.
A purchase that an earlier call handled reports `alreadyProcessed`.

The 6.5.2 SDK binary defines the signed-out code as -1014. Samsung's docs list it as -1015. The
plugin maps both to `accountNotSignedIn`.

`general` is Samsung's catch-all. A -1002 or a raw server code whose detail code names another
kind gets that kind instead, for example `productNotFound` for 9201. Otherwise `detailCode` tells
why:

- 100010: TEST mode, and the user is not a license tester.
- 7002: Samsung blocked the purchase as a suspicious transaction.
- 1005, 1006, 1012 and 1014: Samsung rejected a plan change. See
  [Change a subscription plan](#change-a-subscription-plan).
- 9226: `consume` got a missing or invalid purchase ID. See
  [Consume or acknowledge a purchase](#consume-or-acknowledge-a-purchase).
- 9000, 9005, 9013 and 9014: TEST_FAILURE mode. See
  [Test error handling](#test-error-handling).

Log any other detail code with `details`.

### Test error handling

Initialize with `OperationMode.testFailure` to make every Samsung call fail, so you can test your
error handling without a broken setup. Each call throws `general` with a detail code. Samsung
documents these codes:

| Call | `detailCode` |
|---|---|
| `getOwnedProducts` | 9000 |
| `consume` | 9005 |
| `getProducts` | 9013 |
| `purchase` | 9014 |

A Galaxy S22 returned the documented codes for `getOwnedProducts`, `consume` and `getProducts`.
Samsung documents no code for `acknowledge`, `changeSubscriptionPlan` or `getPromotionEligibility`.
On the S22, `acknowledge` returned 9005 and `getPromotionEligibility` returned 9000.

Samsung checks the Seller Portal setup before it applies TEST_FAILURE. Until the app has IAP
activated and products registered, the calls fail with `productNotFound` and `detailCode` 9201
instead. In TEST_FAILURE mode, `purchase` shows Samsung's test-mode notice and waits until the user
closes it. Calls that the plugin refuses before it calls Samsung, such as `invalidArgument` or
`storeUnavailable`, fail as in the other modes.

## Verify purchases on your server

A user can modify the app, so a server that grants access must check each purchase with
Samsung. Send the `purchaseId` from the app to your server, and have the server call Samsung's
[receipt API][verify_link]. The API takes HTTPS only. Samsung's docs show no authorization header.

```sh
curl "https://iap.samsungapps.com/iap/v6/receipt?purchaseID=<purchaseId>"
```

Grant the purchase only when every check passes:

- `status` is `success`. Samsung also reports `fail` and `cancel`.
- `mode` is `PRODUCTION`. Reject `TEST` on your production server. A TEST purchase costs nothing,
  and any build in TEST mode can make one for a license tester.
- `itemId` is the product the app claims, and `packageName` is the package name of your Galaxy
  build.
- If the app passed `obfuscatedAccountId`, it matches the user who asks for the grant.
- The `purchaseId` is not already granted to another user.

The receipt also has `orderId`, `paymentId`, `consumeYN`, `acknowledgeYN` and dates in GMT. Prefer
these dates to the device-local dates on `OwnedProduct`. This package has no backend code. For
subscription status, use the [Subscription API][subs_api_link], and for server events, use
[Instant Server Notification][isn_link].

## Use with RevenueCat

[RevenueCat][revenuecat_link]'s Flutter SDK, `purchases_flutter`, has no Galaxy Store option up to
version 10.14.0. If you use it for App Store and Google Play, use this plugin in the Galaxy build:

- Do not call `Purchases.configure` with your Google Play key in the Galaxy flavor. RevenueCat would
  then sell through Google Play Billing instead of Samsung IAP.
- Use this plugin for products, purchases and entitlements in the Galaxy flavor. RevenueCat does not
  see these purchases, so the Galaxy build reads entitlements from `getOwnedProducts` or from your
  server.

The `pubspec.yaml` is shared by every flavor. Both stores' billing SDKs are therefore in both APKs,
even though each flavor calls only one. Whether either store accepts that is your app's
responsibility. Check each store's policy.

RevenueCat itself supports Galaxy Store in its native Android SDK, from 10.7.0, and in its React
Native SDK, from 10.3.0. See RevenueCat's [Android installation guide][revenuecat_android_link]. For
Flutter, Studio Pyro maintains a [fork of `purchases_flutter`][revenuecat_fork_link] with a
`purchases_flutter_store_galaxy` package that adds RevenueCat's Galaxy support. With it, RevenueCat
handles Galaxy purchases too, and you do not need this plugin. Depend on the fork with a `git:`
dependency pinned to a `-galaxy.N` tag, never to a branch.

## Test your integration

- **Unit tests.** `SamsungIap` is a const class with instance methods. Pass it to your code instead
  of creating it there, and pass a mock in tests, for example
  `class MockSamsungIap extends Mock implements SamsungIap {}` with mocktail.
- **Device tests.** Use a Samsung device, signed in to Galaxy Store as a license tester, and an app
  build in TEST mode whose package name is registered in Seller Portal. On an emulator, Galaxy Store
  is missing, so every call except `initialize` and `getGalaxyStoreStatus` throws
  `storeUnavailable`.
- **Error handling.** Use TEST_FAILURE mode, as [Test error handling](#test-error-handling)
  describes. Also try the cases that need no special mode: close the payment sheet, turn on
  airplane mode, and disable Galaxy Store in the system settings.
- **Release builds.** Make one purchase with a release build. The plugin ships an R8 keep rule for
  Samsung's IAP service (AIDL) classes, and this check confirms it for your app.
- **Before you submit.** Build with `OperationMode.production`, and test it in a Closed Beta, as
  [Set up Seller Portal](#set-up-seller-portal) describes.

The [example app][example_link] calls every method and shows each result. It starts in TEST mode.

## Limitations

- **Dates are device-local and approximate.** The SDK formats every date on the device without a
  time zone, so the original UTC time is lost. A date can be wrong by the device's offset, and an
  hour is ambiguous when the clocks go back. Use the GMT dates of the server receipt for anything
  that matters.
- **There is no purchase stream.** Each purchase is the result of one `Future`. A purchase whose
  result the app missed shows up only in `getOwnedProducts`.
- **One Flutter engine only.** The plugin queues the calls of one engine. Calls from a second engine
  in the same process can overlap and fail with `busy`.
- **Galaxy Store versions differ.** `acknowledge` needs Galaxy Store 4.5.90 or later. On an older
  version, `OwnedProduct.acknowledgedStatus` reads `unsupported`.
- **Timeouts are fixed.** A call that shows no Samsung UI fails with `network` after 30 seconds.
  `purchase` and `changeSubscriptionPlan` have no timeout.
- **Deprecated SDK fields are not exposed.** The SDK's `isConsumable` and `passThroughParam` have
  no property. Samsung's JSON in `rawJson` still has them.

## License

MIT. See [LICENSE][license_file_link].

[ack_api_link]: https://developer.samsung.com/iap/api/iap-purchase-acknowledgment.html
[example_link]: https://pub.dev/packages/samsung_iap_flutter/example
[iap_api_link]: https://developer.samsung.com/iap/api/get-started.html
[integrate_link]: https://developer.samsung.com/iap/programming-guide/integrate-iap-helper-into-your-app.html
[isn_link]: https://developer.samsung.com/iap/isn/overview.html
[issues_link]: https://github.com/Studio-Pyro/samsung_iap_flutter/issues
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_file_link]: https://github.com/Studio-Pyro/samsung_iap_flutter/blob/main/LICENSE
[license_link]: https://opensource.org/licenses/MIT
[proration_link]: https://developer.samsung.com/iap/subscription-guide/manage-subscription-plan/proration-modes.html
[revenuecat_android_link]: https://www.revenuecat.com/docs/getting-started/installation/android
[revenuecat_fork_link]: https://github.com/Studio-Pyro/purchases-flutter/tree/10.13.2-galaxy.2
[revenuecat_link]: https://www.revenuecat.com
[seller_portal_link]: https://seller.samsungapps.com
[subs_api_link]: https://developer.samsung.com/iap/api/iap-subscription-api.html
[test_modes_link]: https://developer.samsung.com/iap/test-guide/iap-operation-modes.html
[test_prep_link]: https://developer.samsung.com/iap/test-guide/prepare-to-test.html
[test_subs_link]: https://developer.samsung.com/iap/test-guide/test-subscriptions.html
[verify_link]: https://developer.samsung.com/iap/programming-guide/samsung-iap-server-api.html
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
