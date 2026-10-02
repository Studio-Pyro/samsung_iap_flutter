# samsung_iap_flutter example

This app calls every method of `samsung_iap_flutter` and shows each result and error on screen.
`lib/main.dart` has all of the code.

## Run it on a Galaxy device

Samsung IAP needs a Samsung device with Galaxy Store, and an app that is registered in Seller
Portal. On an emulator, the app runs, but every call except `initialize` and
`getGalaxyStoreStatus` fails with `storeUnavailable`.

1. Sign in to Galaxy Store on the device with a license tester account. See
   [Set up Seller Portal][setup_link] in the plugin README.
2. Set the application ID to the package name of your app in Seller Portal. Add this line to
   `android/local.properties`, which git does not track:

   ```properties
   samsungIap.applicationId=<package registered in Seller Portal>
   ```

   Without it, the app uses `dev.studiopyro.samsung_iap_flutter.example`. That package is not
   registered in Seller Portal, so Samsung has no products for it.
3. Run the app:

   ```sh
   flutter run
   ```

   To fetch only some products, pass their IDs:

   ```sh
   flutter run --dart-define=SAMSUNG_IAP_PRODUCT_IDS=<id1>,<id2>
   ```

## Use the app

The app starts in TEST mode, so purchases charge nothing. Only license testers can buy in TEST mode.
Pick another mode at the top of the screen before you tap **Initialize**:

- `production` makes real payments. Use it only with a build from a Closed Beta or the store.
- `testFailure` makes every Samsung call fail, to show the error that each call reports.

Then tap **Initialize**, **Get products** and **Get owned products**. Each product has a **Buy**
button, and each owned product has **Consume** and **Acknowledge** buttons. When the products
include subscriptions, the app also shows a plan changer and a badge for each offer the user can
get.

## Integration tests

`integration_test/` holds the plugin's own tests. The
[repository README][repo_readme_link] describes how to run them.

[repo_readme_link]: https://github.com/Studio-Pyro/samsung_iap_flutter#integration-tests
[setup_link]: https://pub.dev/packages/samsung_iap_flutter#set-up-seller-portal
