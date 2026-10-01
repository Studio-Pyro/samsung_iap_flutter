package com.example.verygoodcore

import SamsungIapFlutterApi
import io.flutter.embedding.engine.plugins.FlutterPlugin

class SamsungIapFlutterPlugin : FlutterPlugin, SamsungIapFlutterApi {
    companion object {
        private const val TAG = "SamsungIapFlutterPlugin"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        SamsungIapFlutterApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        SamsungIapFlutterApi.setUp(binding.binaryMessenger, null)
    }

    override fun getPlatformName(callback: (Result<String?>) -> Unit) {
        callback(Result.success("Android ${android.os.Build.VERSION.RELEASE}"))
    }
}