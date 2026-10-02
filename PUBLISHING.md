# Publishing samsung_iap_flutter

This document describes how to publish `samsung_iap_flutter` and its federated packages to
[pub.dev][pub_dev_link] under the verified publisher `studiopyro.dev`.

Because `samsung_iap_flutter` is a [federated plugin][federated_plugins_link], each package is
published on its own, and the packages depend on each other by version. In this repository, the
committed `pubspec_overrides.yaml` files point those versions at the local sources, as
[Set up a checkout](README.md#set-up-a-checkout) describes. You replace and restore nothing when you
publish.

## Packages

`samsung_iap_flutter` is composed of the following packages:

- `samsung_iap_flutter_platform_interface`, the common platform interface.
- `samsung_iap_flutter_android`, the Android implementation.
- `samsung_iap_flutter`, the app-facing package that users depend on.

## Versioning

Each package has its own `version` in its `pubspec.yaml` and its own `CHANGELOG.md`. You can release
them independently, but keep the following in mind:

- The platform interface uses semantic versioning. A breaking change to it needs a coordinated
  release of every package that depends on it.
- When a package needs a newer version of a sibling, raise its version constraint, for example to
  `^0.2.0`. The overrides hide a constraint that is too low, so check each constraint before you
  publish.

## Set up the verified publisher

Do this once, before the first publish. Use one Google account for every step.

1. In [Google Search Console][search_console_link], add `studiopyro.dev` as a **Domain** property
   and verify it with the DNS TXT record that Search Console gives you.
2. Sign in to pub.dev and open [Create publisher][create_publisher_link]. Enter `studiopyro.dev`
   and finish the verification.
3. Optional: in the publisher's **Admin** tab, add the other maintainers as members.

## Before publishing

1. Update each package's `CHANGELOG.md` with the changes since the previous release.
2. Bump the `version` field in each package's `pubspec.yaml`.
3. Commit the changes. pub warns about a dirty git state.
4. Run a dry run in each package, in the publishing order below:

```sh
cd samsung_iap_flutter_platform_interface && flutter pub publish --dry-run
cd ../samsung_iap_flutter_android && flutter pub publish --dry-run
cd ../samsung_iap_flutter && flutter pub publish --dry-run
```

The dry run of the android and app-facing packages reports that non-dev dependencies are
overridden in `pubspec_overrides.yaml`, once for each overridden package. That hint is expected.
Resolve every other warning or error before you continue.

## Publishing order

Publish the platform interface first, then the Android implementation, then the app-facing package.
Each package needs the packages it depends on to be on pub.dev already.

```sh
cd samsung_iap_flutter_platform_interface
flutter pub publish

cd ../samsung_iap_flutter_android
flutter pub publish

cd ../samsung_iap_flutter
flutter pub publish
```

## After publishing

1. Open each new package on pub.dev. In its **Admin** tab, transfer it to the `studiopyro.dev`
   publisher. A package that already belongs to the publisher needs no transfer.
2. Raise the pana minimum scores, as [pana minimum scores](#pana-minimum-scores) describes.

## pana minimum scores

pana resolves each package's dependencies from pub.dev, and it checks the pubspec `repository` URL
against the pubspec on `main`. Until both work, a package cannot reach 160 points, so each `pana`
job in `.github/workflows/` has a lower `min_score`:

- `samsung_iap_flutter_platform_interface.yaml` has 150. The platform interface loses 10 points only
  while the pubspec on `main` has no `repository` URL. A pull request's pana run reads `main`, not
  the pull request, so the pull request that adds the URL cannot pass 160 itself. Raise the minimum
  to 160 in the next pull request after that one merges.
- `samsung_iap_flutter_android.yaml` and `samsung_iap_flutter.yaml` have 40. pana cannot resolve
  their sibling dependencies until those are on pub.dev. Raise each minimum to 160 after the first
  release.

For more information about publishing Dart and Flutter packages, see Flutter's
[official documentation on publishing packages][publishing_packages_link] and the pub.dev page on
[verified publishers][verified_publishers_link].

[create_publisher_link]: https://pub.dev/create-publisher
[federated_plugins_link]: https://docs.flutter.dev/packages-and-plugins/developing-packages#federated-plugins
[pub_dev_link]: https://pub.dev
[publishing_packages_link]: https://docs.flutter.dev/packages-and-plugins/developing-packages#publish
[search_console_link]: https://search.google.com/search-console
[verified_publishers_link]: https://dart.dev/tools/pub/verified-publishers
