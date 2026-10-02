// Apps use `samsung_iap_flutter`, not this package. This example is for a
// platform implementation: it extends SamsungIapFlutterPlatform and registers
// itself. A method it does not override throws UnimplementedError.
import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

class FakeSamsungIapPlatform extends SamsungIapFlutterPlatform {
  @override
  Future<GalaxyStoreStatus> getGalaxyStoreStatus() async =>
      GalaxyStoreStatus.available;
}

Future<void> main() async {
  SamsungIapFlutterPlatform.instance = FakeSamsungIapPlatform();
  final status = await SamsungIapFlutterPlatform.instance
      .getGalaxyStoreStatus();
  assert(status == GalaxyStoreStatus.available, 'the fake is registered');
}
