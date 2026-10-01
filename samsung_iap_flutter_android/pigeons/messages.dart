// SamsungIapFlutterApi must be abstract.

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartPackageName: 'samsung_iap_flutter_android',
    kotlinOut: 'android/src/main/kotlin/dev/studiopyro/samsung_iap_flutter/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'dev.studiopyro.samsung_iap_flutter'),
    copyrightHeader: 'pigeons/copyright.txt',
  ),
)
@HostApi()
abstract class SamsungIapFlutterApi {
  @async
  String? getPlatformName();
}
