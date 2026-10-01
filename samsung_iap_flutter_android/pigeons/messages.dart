// SamsungIapFlutterApi must be abstract.

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartPackageName: 'samsung_iap_flutter',
    kotlinOut: 'android/src/main/kotlin/com/example/verygoodcore/Messages.g.kt',
    kotlinOptions: KotlinOptions(),
    copyrightHeader: 'pigeons/copyright.txt',
  ),
)
@HostApi()
abstract class SamsungIapFlutterApi {
  @async
  String? getPlatformName();
}
