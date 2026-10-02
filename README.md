# samsung_iap_flutter

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

This repository holds `samsung_iap_flutter`, an unofficial Flutter plugin for Samsung In-App
Purchase on Galaxy Store. This README is for people who work on the plugin. To use the plugin in an
app, read the [`samsung_iap_flutter` README](samsung_iap_flutter/README.md), which is also its
pub.dev page.

The repository started from the [Very Good CLI][very_good_cli_link] federated plugin template.

## Packages

The plugin is a [federated plugin][federated_plugins_link] of three packages:

| Package | What it owns |
|---|---|
| `samsung_iap_flutter_platform_interface` | Every public model, enum and `SamsungIapException`, the parsing rules, and the `SamsungIapFlutterPlatform` base class. |
| `samsung_iap_flutter_android` | The Pigeon schema and its generated Dart and Kotlin code, the Kotlin plugin that calls Samsung IAP SDK 6.5.2, the Dart call queue, and the mapping from Pigeon types and error codes to the public types. |
| `samsung_iap_flutter` | The `SamsungIap` class that apps use. It checks arguments before it calls the platform, and it re-exports the platform interface. |

A call from an app goes through these files:

1. `samsung_iap_flutter/lib/samsung_iap_flutter.dart` checks the arguments and calls
   `SamsungIapFlutterPlatform.instance`.
2. `samsung_iap_flutter_android/lib/samsung_iap_flutter_android.dart` queues the call, so only one
   runs at a time, and calls the Pigeon host API in `lib/src/messages.g.dart`.
3. `SamsungIapFlutterPlugin.kt` checks Galaxy Store, starts the SDK call through `awaitSdk`, and
   returns its one result. `awaitSdk` turns a `false` return into `not_sent`. The calls that show no
   Samsung UI pass it a 30-second timeout.
4. Back in Dart, `lib/src/mappers.dart` maps the result to the public models, and
   `lib/src/errors.dart` maps a `PlatformException` to `SamsungIapException`.

`docs/research/samsung-iap-flutter-bridge.md` records the SDK research and every design decision,
with sources.

## Set up a checkout

Each pubspec names its sibling packages by version, as pub.dev requires. The committed
`pubspec_overrides.yaml` files in `samsung_iap_flutter_android`, `samsung_iap_flutter` and
`samsung_iap_flutter/example` point those dependencies at the sources in this repository. Run
`flutter pub get` in a package, and it builds against this checkout. pub leaves
`pubspec_overrides.yaml` out of a published package.

## CI

| Workflow | Runs on | Jobs |
|---|---|---|
| `ci.yaml` | Every pull request to `main` | Checks that the PR title is a semantic commit message. |
| `spell_check.yaml` | Every pull request, and pushes to `main` that change Markdown or `.github/cspell.json` | Runs cspell on every Markdown file, and on the PR title. |
| `license_check.yaml` | Changes to a package's `pubspec.yaml` | Checks that every dependency has an allowed license. |
| `samsung_iap_flutter_platform_interface.yaml` | Changes to the platform interface | Analyzes, formats and tests the package. Runs pana. |
| `samsung_iap_flutter_android.yaml` | Changes to the android package or the example's `android/` | Analyzes, formats and tests the package. Runs pana. Checks that the Pigeon output is current, and runs the Kotlin unit tests. |
| `samsung_iap_flutter.yaml` | Changes to any package | Analyzes, formats and tests the app-facing package. Runs pana. Runs `integration_test/app_test.dart` on an API 34 emulator. |

pana resolves dependencies from pub.dev and checks each pubspec against the one on `main`. Until the
packages are published, each pana job has a minimum score below 160. A comment on each job says when
to raise it.

## Integration tests

The integration tests use [`integration_test`][integration_test_link] and live in the example app of the
app-facing package `samsung_iap_flutter`. Put each test in one of three files:

- `integration_test/app_test.dart` is for tests that run on any Android emulator. They do not need
  Galaxy Store. CI runs this file.
- `integration_test/device_test.dart` is for tests that need a Samsung device with Galaxy Store and a
  license tester account. CI does not run this file.
- `integration_test/failure_mode_test.dart` is for tests on the same device in TEST_FAILURE mode.
  CI does not run this file.

Run the emulator tests on a connected emulator or device:

```sh
cd samsung_iap_flutter/example
flutter test integration_test/app_test.dart
```

Device tests must use the application ID that is registered in Seller Portal. Set it in
`samsung_iap_flutter/example/android/local.properties`, which is not committed. Without this key, the
example uses `dev.studiopyro.samsung_iap_flutter.example`.

```properties
samsungIap.applicationId=<package registered in Seller Portal>
```

Then run the device tests on the Samsung device. They use TEST mode, so sign in to Galaxy Store as a
license tester. Pass the product IDs to fetch as a comma-separated list. Without the define, the
tests fetch every product of the app. Pass the IDs of products the tester already owns in
`SAMSUNG_IAP_OWNED_IDS`, and the tests check that each one is in the owned list. Without it, the
tests check the fields of whatever the tester owns.

```sh
cd samsung_iap_flutter/example
flutter test integration_test/device_test.dart \
  --dart-define=SAMSUNG_IAP_PRODUCT_IDS=<id1>,<id2> \
  --dart-define=SAMSUNG_IAP_OWNED_IDS=<owned id>
```

The purchase test is interactive and is skipped unless you pass `SAMSUNG_IAP_PURCHASE_ID`. Use an
item the tester does not own yet, because buying an owned item fails with `alreadyOwned`. The test
starts `getOwnedProducts` and then `purchase` at once, so it also checks that a purchase queued
behind an inquiry is not refused. When Samsung's TEST-mode payment sheet opens, tap through it on
the device. The test then checks that the new purchase is in the owned list.

```sh
flutter test integration_test/device_test.dart \
  --dart-define=SAMSUNG_IAP_PURCHASE_ID=<unowned item id>
```

The consume and acknowledge tests are interactive too, and each needs its own item that the tester
does not own:

- With `SAMSUNG_IAP_CONSUME_ID`, the test buys the item, consumes it, and buys it again to show it
  can be bought again. It then consumes the second and first purchases together, and expects
  `success` and `alreadyProcessed`. Last, it consumes the second purchase with a bogus purchase ID,
  and expects `alreadyProcessed` and `invalidPurchaseId`. Tap through two payment sheets.

  The two batch checks are open acceptance items. Samsung documents both a per-purchase
  `invalidPurchaseId` and a whole-call error with detail code 9226 for a bad ID. If the last call
  fails with `general` and `detailCode: 9226`, Samsung fails the whole batch. Change the test and
  the package README to match.
- With `SAMSUNG_IAP_ACKNOWLEDGE_ID`, the test buys the item and checks that it is owned and
  `notAcknowledged`. It then acknowledges it, checks that it is `acknowledged`, and checks that a
  second acknowledge reports `alreadyProcessed`. Tap through one payment sheet.

```sh
flutter test integration_test/device_test.dart \
  --dart-define=SAMSUNG_IAP_CONSUME_ID=<unowned item id> \
  --dart-define=SAMSUNG_IAP_ACKNOWLEDGE_ID=<another unowned item id>
```

In TEST mode, Samsung lets the tester buy an acknowledged item again after 10 minutes. Wait that
long before you run the acknowledge test again with the same item.

The plan-change tests are interactive and need two tiers of one subscription. Subscribe the tester
to the cheaper tier first, for example with the example app. Pass the cheaper tier in
`SAMSUNG_IAP_PLAN_FROM_ID` and the pricier tier in `SAMSUNG_IAP_PLAN_TO_ID`:

- The upgrade test changes the plan to the pricier tier with `instantProratedDate`. It checks that
  the new purchase is for that tier and that it is in the owned list. Tap through the plan-change
  UI.
- The downgrade test then tries to change back with `instantProratedCharge`, which Samsung allows
  only for upgrades. It expects a `general` error whose detail code is not one of the documented
  plan-change codes (1005, 1006, 1012 and 1014), and prints it. Record the detail code in the test,
  where a TODO marks the place.

Each run leaves the tester on the pricier tier. To reset it before the next run:

1. In the example app, change the plan back to the cheaper tier with `deferred`, as in manual
   check 11 below.
2. Wait for the next renewal. In TEST mode, a subscription period is 10 minutes.

Until that renewal, Samsung refuses further changes, and the upgrade test most likely fails with
detail code 1014. The same applies if Samsung ever accepts the instant downgrade and schedules it
for the renewal.

```sh
flutter test integration_test/device_test.dart \
  --dart-define=SAMSUNG_IAP_PLAN_FROM_ID=<cheaper tier id> \
  --dart-define=SAMSUNG_IAP_PLAN_TO_ID=<pricier tier id>
```

The promotion test needs a subscription with a free trial that the tester has never subscribed to.
Pass it in `SAMSUNG_IAP_TRIAL_ID`, and the test checks that Samsung reports `freeTrial` for it. The
test is not interactive and buys nothing.

```sh
flutter test integration_test/device_test.dart \
  --dart-define=SAMSUNG_IAP_TRIAL_ID=<trial subscription id>
```

The failure-mode tests run all seven Samsung calls in TEST_FAILURE mode, where Samsung fails every
request on purpose. They need no product IDs and buy nothing. Each test expects `general` and prints
the detail code. The tests turn off Samsung's error dialogs and check that no error reports one. If
`purchase` or `changeSubscriptionPlan` opens Samsung UI, close it.

```sh
flutter test integration_test/failure_mode_test.dart
```

Samsung documents a detail code for four of the calls, and the tests assert those codes. No device
run has confirmed them yet. For the other three calls, the tests check only that a detail code is
present, because a code Samsung does not document is not a contract. Record each code you observe in
this table.

| Call | Expected `detailCode` | Observed |
|---|---|---|
| `getProducts` | 9013 (documented, unverified) | Not run yet |
| `getOwnedProducts` | 9000 (documented, unverified) | Not run yet |
| `purchase` | 9014 (documented, unverified) | Not run yet |
| `consume` | 9005 (documented, unverified) | Not run yet |
| `acknowledge` | Not documented | Not run yet |
| `changeSubscriptionPlan` | Not documented | Not run yet |
| `getPromotionEligibility` | Not documented | Not run yet |

Some checks cannot be automated. Do them by hand in the example app, which starts in TEST mode:

1. Disable Galaxy Store in the system settings.
2. Tap **Initialize**. The app shows `Galaxy Store: disabled`.
3. Tap **Get products**. The app shows a `storeUnavailable` error at once, without a Samsung dialog.
4. Tap **Get owned products**. The app shows the same error.
5. Enable Galaxy Store again.
6. Tap **Initialize**, **Get products** and then **Buy** on a product. Close the payment sheet
   without paying. The app shows `Cancelled` and no error.
7. Tap **Buy** on a product the tester already owns. The app shows an `alreadyOwned` error.
8. Check a purchase that starts while the app is in the background. Start the device purchase
   test, which calls `getOwnedProducts` and `purchase` together, and press **Home** at once. Wait
   30 seconds, then return to the app. The payment sheet appears and the test passes. If the test
   fails with its 5-minute timeout instead, the purchase hung, and every later call waits behind
   it.
9. Tap **Get owned products**, then **Consume** on an owned item. The app shows
   `Consume <purchase ID>: success (0)`. Tap **Get products** and **Buy** on the same item. The
   payment sheet opens instead of an `alreadyOwned` error.
10. Tap **Acknowledge** on an owned subscription or item. The app shows
    `Acknowledge <purchase ID>: success (0)`, and the reloaded row shows `acknowledged`. Tap
    **Acknowledge** again. The app shows `alreadyProcessed (4)`.
11. Tap **Get products**. Below the products, pick the subscribed tier in **From**, a cheaper tier
    in **To**, and `instantProratedCharge`. Tap **Change plan**. The app shows the error and its
    detail code. Pick `deferred`, tap **Change plan** again and complete the plan-change UI. The
    app shows `Changed to <product ID>` with the purchase and order IDs.
12. Check the signed-out error. Sign out of the Samsung account on the device, and keep Galaxy Store
    enabled. Tap **Initialize**, **Get products**, **Get owned products** and **Buy** on a product.
    Close any Samsung sign-in prompt without signing in. Expect `accountNotSignedIn` with code
    -1014, which the 6.5.2 SDK binary defines, or -1015, which Samsung's docs list. Record which
    code each call shows on the next line. If every call shows the sign-in prompt instead of an
    error, record the mapping as unobservable there. Sign in again as the license tester.

    Observed: not run yet.
13. Check that a free trial does not apply again, after a purchase and after a re-subscription. This
    step uses up the trial for the tester, so do it last, with the subscription you passed in
    `SAMSUNG_IAP_TRIAL_ID`. To run the promotion test again, use a different tester or a new
    subscription.
    1. Tap **Get products**. The row of the trial subscription shows **Free trial available**.
    2. Tap **Buy** on it and complete the payment. Tap **Get products** again. The badge is gone.
    3. In Galaxy Store, open **Menu > Subscription**, select the subscription and tap
       **Unsubscribe**. In TEST mode, the subscription expires at the end of its 10-minute cycle,
       for example at hh:10 or hh:20. Wait until then.
    4. Tap **Get products**. The badge is still gone. Tap **Buy** on the subscription and complete
       the payment, then tap **Get products** again. The badge is still gone.

    The README of the `samsung_iap_flutter` package expects `regularPrice` after a purchase and
    after a re-subscription. If the badge comes back in either check, update that README.

Then check the R8 keep rules of the plugin. Run a minified release build, tap **Buy** on a product the
tester does not own, and complete the payment. The app shows the purchase and order IDs.

```sh
flutter run --release
```

## Pigeon bindings

`samsung_iap_flutter_android/pigeons/messages.dart` defines the platform channel. After you change it,
regenerate the Dart and Kotlin bindings and format the Dart output. CI fails when the committed
bindings differ from the generated ones.

```sh
cd samsung_iap_flutter_android
dart run pigeon --input pigeons/messages.dart
dart format lib/src/messages.g.dart
```

## Kotlin unit tests

The JVM unit tests of `samsung_iap_flutter_android` run through the Gradle project of the example app:

```sh
cd samsung_iap_flutter/example
flutter build apk --debug --config-only
cd android
./gradlew :samsung_iap_flutter_android:testDebugUnitTest
```

## Publishing

[`PUBLISHING.md`](PUBLISHING.md) describes how to release the packages and the order to publish
them in.

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
[very_good_cli_link]: https://github.com/VeryGoodOpenSource/very_good_cli
[integration_test_link]: https://docs.flutter.dev/testing/integration-tests
[federated_plugins_link]: https://docs.flutter.dev/packages-and-plugins/developing-packages#federated-plugins
