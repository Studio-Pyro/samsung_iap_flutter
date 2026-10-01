# Publishing `samsung_iap_flutter` 📦

This document describes how to publish `samsung_iap_flutter` and its federated packages to [pub.dev][pub_dev_link].

Because `samsung_iap_flutter` is a [federated plugin][federated_plugins_link], each package is published independently and they depend on each other by version. The packages live side-by-side in this repository and reference each other through [path dependencies][path_dependencies_link] during development. Path dependencies are **not** allowed by `pub.dev`, so they must be replaced with version dependencies before publishing.

## Packages

`samsung_iap_flutter` is composed of the following packages:

- `samsung_iap_flutter_platform_interface` — the common platform interface.
- `samsung_iap_flutter_android` — the Android implementation.
- `samsung_iap_flutter` — the front-facing app-facing package that users depend on.

## Versioning ⚖️

Each package has its own `version` in its `pubspec.yaml` and its own `CHANGELOG.md`. They can be released independently, but keep the following in mind:

- The platform interface uses semantic versioning, and a **breaking change** to it requires a coordinated release of every implementation that depends on it.
- When the front-facing package is updated, make sure its version constraints on the platform implementations and the platform interface still resolve to the versions you intend to ship.

## Before publishing ✅

1. Update each package's `CHANGELOG.md` with the changes since the previous release.
2. Bump the `version` field in each package's `pubspec.yaml`.
3. Replace [path dependencies][path_dependencies_link] with version dependencies in every package that depends on another federated package.

For example, in `samsung_iap_flutter/pubspec.yaml` replace:

```yaml
dependencies:
  samsung_iap_flutter_platform_interface:
    path: ../samsung_iap_flutter_platform_interface
```

with:

```yaml
dependencies:
  samsung_iap_flutter_platform_interface: ^<version>
```

Apply the same change to every platform implementation package that depends on `samsung_iap_flutter_platform_interface`.

4. Verify each package with a dry run before publishing:

```sh
dart pub publish --dry-run
```

Resolve every warning or error reported by the dry run before continuing.

## Publishing order 🚀

The platform interface must be published **first**, so that the platform implementations can resolve it. Then publish each platform implementation, and finally publish the front-facing package:

```sh
# 1. Publish the platform interface first.
cd samsung_iap_flutter_platform_interface
dart pub publish

# 2. Publish each platform implementation.
cd ../samsung_iap_flutter_android
dart pub publish

# 3. Publish the front-facing package last.
cd ../samsung_iap_flutter
dart pub publish
```

💡 **Note**: Publishing the platform implementations and front-facing package **before** the platform interface is published will fail, because they cannot resolve their dependency on `samsung_iap_flutter_platform_interface`.

## After publishing 🧹

After publishing, restore the [path dependencies][path_dependencies_link] in each package so local development continues to work against the in-repository sources. Alternatively, you can keep the version dependencies on `main` and use `dependency_overrides` locally — pick the workflow that best fits your team.

For more information about publishing Dart and Flutter packages, see Flutter's [official documentation on publishing packages][publishing_packages_link].

[federated_plugins_link]: https://docs.flutter.dev/packages-and-plugins/developing-packages#federated-plugins
[path_dependencies_link]: https://dart.dev/tools/pub/dependencies#path-packages
[pub_dev_link]: https://pub.dev
[publishing_packages_link]: https://docs.flutter.dev/packages-and-plugins/developing-packages#publish
