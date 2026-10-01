# samsung_iap_flutter_android

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]

The Android implementation of `samsung_iap_flutter`.

## Usage

This package is [endorsed][endorsed_link], which means you can simply use `samsung_iap_flutter`
normally. This package will be automatically included in your app when you do.

## Regenerating the Pigeon bindings

`pigeons/messages.dart` defines the platform channel. After changing it, regenerate the Dart and
Kotlin bindings from this directory. CI checks formatting, so format the generated Dart file too:

```sh
dart run pigeon --input pigeons/messages.dart
dart format lib/src/messages.g.dart
```

## Kotlin unit tests

The JVM unit tests run through the example app's Gradle project:

```sh
cd ../samsung_iap_flutter/example
flutter build apk --debug --config-only
cd android
./gradlew :samsung_iap_flutter_android:testDebugUnitTest
```

[endorsed_link]: https://flutter.dev/docs/development/packages-and-plugins/developing-packages#endorsed-federated-plugin
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis