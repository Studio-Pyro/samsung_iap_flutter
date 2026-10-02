# Publishing samsung_iap_flutter

This document describes how to publish `samsung_iap_flutter` and its federated packages to
[pub.dev][pub_dev_link] under the verified publisher `studiopyro.dev`.

Because `samsung_iap_flutter` is a [federated plugin][federated_plugins_link], each package is
published on its own, and the packages depend on each other by version. Each `pubspec.yaml` names
its sibling packages by version, for example `samsung_iap_flutter_platform_interface: ^0.1.0`. A
committed `pubspec_overrides.yaml` in the android package, the app-facing package and the example
points those dependencies at the sources in this repository. pub leaves `pubspec_overrides.yaml` out
of a published package, so you replace and restore nothing when you publish.

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
```

The dry run of the android and app-facing packages reports one hint, that non-dev dependencies are
overridden in `pubspec_overrides.yaml`. That hint is expected. Resolve every other warning or error
before you continue.

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
2. After the first release, raise `min_score` of the `pana` job to 160 in
   `.github/workflows/samsung_iap_flutter_platform_interface.yaml`,
   `.github/workflows/samsung_iap_flutter_android.yaml` and
   `.github/workflows/samsung_iap_flutter.yaml`.

For more information about publishing Dart and Flutter packages, see Flutter's
[official documentation on publishing packages][publishing_packages_link] and the pub.dev page on
[verified publishers][verified_publishers_link].

[create_publisher_link]: https://pub.dev/create-publisher
[federated_plugins_link]: https://docs.flutter.dev/packages-and-plugins/developing-packages#federated-plugins
[pub_dev_link]: https://pub.dev
[publishing_packages_link]: https://docs.flutter.dev/packages-and-plugins/developing-packages#publish
[search_console_link]: https://search.google.com/search-console
[verified_publishers_link]: https://dart.dev/tools/pub/verified-publishers
