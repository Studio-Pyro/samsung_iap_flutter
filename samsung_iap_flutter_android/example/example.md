# Example

Apps do not use this package directly. Add [`samsung_iap_flutter`][app_facing_link] to your app,
and Flutter includes this Android implementation automatically.

```dart
import 'package:samsung_iap_flutter/samsung_iap_flutter.dart';

const iap = SamsungIap();

Future<List<SamsungProduct>> loadProducts() async {
  await iap.initialize(mode: OperationMode.test);
  return iap.getProducts();
}
```

For a complete app, see the [example of `samsung_iap_flutter`][example_link].

[app_facing_link]: https://pub.dev/packages/samsung_iap_flutter
[example_link]: https://pub.dev/packages/samsung_iap_flutter/example
