package dev.studiopyro.samsung_iap_flutter

import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertTrue

class SamsungIapFlutterPluginTest {
    @Test
    fun getPlatformNameReportsAndroid() = runTest {
        val name = SamsungIapFlutterPlugin().getPlatformName()

        assertTrue(name.startsWith("Android"), "was: $name")
    }
}
