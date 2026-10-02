# samsung_iap_flutter_platform_interface

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]

The common platform interface of [`samsung_iap_flutter`][app_facing_link], an unofficial Flutter
plugin for Samsung In-App Purchase on Galaxy Store. Studio Pyro maintains it, and it is not
affiliated with or endorsed by Samsung. It holds the models, the enums, `SamsungIapException` and
the `SamsungIapFlutterPlatform` base class.

## Usage

Apps do not depend on this package directly. Add `samsung_iap_flutter` to your app. It re-exports
every public type of this package.

To write a platform implementation, extend `SamsungIapFlutterPlatform` and set
`SamsungIapFlutterPlatform.instance` to your implementation when it registers. Extend the class
with `extends`, not `implements`. The base class checks this, and a method added in a later version
then throws `UnimplementedError` in your implementation instead of breaking its build.

[app_facing_link]: https://pub.dev/packages/samsung_iap_flutter
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
