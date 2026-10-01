package dev.studiopyro.samsung_iap_flutter

import io.flutter.embedding.engine.plugins.FlutterPlugin

class SamsungIapFlutterPlugin : FlutterPlugin, SamsungIapFlutterApi {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        SamsungIapFlutterApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        SamsungIapFlutterApi.setUp(binding.binaryMessenger, null)
    }

    override suspend fun getPlatformName(): String = "Android ${android.os.Build.VERSION.RELEASE}"
}
