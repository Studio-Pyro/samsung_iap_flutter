package dev.studiopyro.samsung_iap_flutter

import android.content.Context
import com.samsung.android.sdk.iap.lib.constants.HelperDefine.OperationMode
import com.samsung.android.sdk.iap.lib.helper.IapHelper
import com.samsung.android.sdk.iap.lib.listener.OnGetProductsDetailsListener
import com.samsung.android.sdk.iap.lib.vo.ErrorVo
import com.samsung.android.sdk.iap.lib.vo.ProductVo
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.mockito.ArgumentMatchers.any
import org.mockito.ArgumentMatchers.anyString
import org.mockito.ArgumentMatchers.eq
import org.mockito.Mockito.doAnswer
import org.mockito.Mockito.mock
import org.mockito.Mockito.never
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertTrue
import kotlin.time.Duration.Companion.hours
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.Duration.Companion.seconds

@OptIn(ExperimentalCoroutinesApi::class)
class SamsungIapFlutterPluginTest {
    private val helper = mock(IapHelper::class.java)
    private var store = PlatformStoreStatus.AVAILABLE

    private fun attachedPlugin(
        helperFactory: (Context) -> IapHelper = { helper },
    ): SamsungIapFlutterPlugin {
        val binding = mock(FlutterPlugin.FlutterPluginBinding::class.java)
        `when`(binding.applicationContext).thenReturn(mock(Context::class.java))
        `when`(binding.binaryMessenger).thenReturn(mock(BinaryMessenger::class.java))
        return SamsungIapFlutterPlugin(helperFactory = helperFactory, storeStatus = { store })
            .apply { onAttachedToEngine(binding) }
    }

    private fun initializedPlugin() =
        attachedPlugin().apply { initialize(PlatformOperationMode.TEST, showErrorDialog = false) }

    private fun answerProducts(vararg replies: Pair<ErrorVo, ArrayList<ProductVo>>) {
        doAnswer { invocation ->
            val listener = invocation.getArgument<OnGetProductsDetailsListener>(1)
            replies.forEach { (error, products) -> listener.onGetProducts(error, products) }
            null
        }.`when`(helper).getProductsDetails(anyString(), any())
    }

    private fun errorVo(code: Int): ErrorVo = mock(ErrorVo::class.java).also {
        `when`(it.errorCode).thenReturn(code)
        `when`(it.errorString).thenReturn("Product does not exist.")
        `when`(it.errorDetailsString).thenReturn("IS9207/6050/x")
        `when`(it.isShowDialog).thenReturn(true)
    }

    private fun productVo(id: String): ProductVo = mock(ProductVo::class.java).also {
        `when`(it.itemId).thenReturn(id)
        `when`(it.itemPrice).thenReturn(7.99)
        `when`(it.type).thenReturn("subscription")
        `when`(it.subscriptionDurationUnit).thenReturn("MONTH")
        `when`(it.jsonString).thenReturn("""{"mItemId":"$id"}""")
    }

    @Test
    fun initializeMapsEveryOperationMode() {
        val expected = mapOf(
            PlatformOperationMode.PRODUCTION to OperationMode.OPERATION_MODE_PRODUCTION,
            PlatformOperationMode.TEST to OperationMode.OPERATION_MODE_TEST,
            PlatformOperationMode.TEST_FAILURE to OperationMode.OPERATION_MODE_TEST_FAILURE,
        )
        assertEquals(PlatformOperationMode.entries.toSet(), expected.keys)

        expected.forEach { (mode, sdkMode) ->
            attachedPlugin().initialize(mode, showErrorDialog = true)
            verify(helper).setOperationMode(sdkMode)
        }
    }

    @Test
    fun initializePassesShowErrorDialog() {
        attachedPlugin().initialize(PlatformOperationMode.PRODUCTION, showErrorDialog = false)

        verify(helper).setShowErrorDialog(false)
    }

    @Test
    fun getStoreStatusReportsTheStoreCheck() {
        store = PlatformStoreStatus.DISABLED

        assertEquals(PlatformStoreStatus.DISABLED, attachedPlugin().getStoreStatus())
    }

    @Test
    fun getProductsDetailsReturnsMappedProducts() = runTest {
        answerProducts(errorVo(0) to arrayListOf(productVo("monthly")))

        val products = initializedPlugin().getProductsDetails("monthly")

        assertEquals(1, products.size)
        with(products.single()) {
            assertEquals("monthly", itemId)
            assertEquals(7.99, itemPrice)
            assertEquals("subscription", type)
            assertEquals("MONTH", subscriptionDurationUnit)
            assertEquals("""{"mItemId":"monthly"}""", json)
            assertEquals("", itemName, "null getters arrive as empty strings")
            assertEquals("", freeTrialPeriod, "null getters arrive as empty strings")
        }
        verify(helper).getProductsDetails(eq("monthly"), any())
    }

    @Test
    fun getProductsDetailsReturnsAnEmptyCatalog() = runTest {
        answerProducts(errorVo(0) to arrayListOf())

        assertEquals(emptyList(), initializedPlugin().getProductsDetails(""))
    }

    @Test
    fun getProductsDetailsThrowsTheSdkError() = runTest {
        answerProducts(errorVo(-1005) to arrayListOf())

        val error = assertFailsWith<FlutterError> { initializedPlugin().getProductsDetails("x") }

        assertEquals("sdk", error.code)
        assertEquals("Product does not exist.", error.message)
        assertEquals(
            mapOf("errorCode" to -1005, "errorDetails" to "IS9207/6050/x", "dialogShown" to true),
            error.details,
        )
    }

    @Test
    fun getProductsDetailsKeepsOnlyTheFirstOfTwoCallbacks() = runTest {
        answerProducts(
            errorVo(0) to arrayListOf(productVo("first")),
            errorVo(-1008) to arrayListOf(),
            errorVo(0) to arrayListOf(productVo("third")),
        )

        val products = initializedPlugin().getProductsDetails("")

        assertEquals(listOf("first"), products.map { it.itemId })
    }

    @Test
    fun getProductsDetailsWaitsForALaterCallback() = runTest {
        var listener: OnGetProductsDetailsListener? = null
        doAnswer { listener = it.getArgument(1); null }
            .`when`(helper).getProductsDetails(anyString(), any())
        val plugin = initializedPlugin()

        val result = async { plugin.getProductsDetails("") }
        runCurrent()
        assertFalse(result.isCompleted)
        listener!!.onGetProducts(errorVo(0), arrayListOf(productVo("late")))

        assertEquals(listOf("late"), result.await().map { it.itemId })
    }

    @Test
    fun getProductsDetailsFailsBeforeTheSdkWhenTheStoreIsUnusable() = runTest {
        store = PlatformStoreStatus.NOT_INSTALLED

        val error = assertFailsWith<FlutterError> { initializedPlugin().getProductsDetails("") }

        assertEquals("store_unavailable", error.code)
        assertEquals("notInstalled", error.details)
        verify(helper, never()).getProductsDetails(anyString(), any())
    }

    @Test
    fun getProductsDetailsBeforeInitializeFails() = runTest {
        val error = assertFailsWith<FlutterError> { attachedPlugin().getProductsDetails("") }

        assertEquals("not_initialized", error.code)
        verify(helper, never()).getProductsDetails(anyString(), any())
    }

    @Test
    fun getProductsDetailsAfterAFailedInitializeFails() = runTest {
        val plugin = attachedPlugin(helperFactory = { throw IllegalStateException("no SDK") })

        assertFailsWith<IllegalStateException> {
            plugin.initialize(PlatformOperationMode.TEST, showErrorDialog = true)
        }
        val error = assertFailsWith<FlutterError> { plugin.getProductsDetails("") }

        assertEquals("not_initialized", error.code)
    }

    @Test
    fun getProductsDetailsTimesOutAfter30Seconds() = runTest {
        doAnswer { null }.`when`(helper).getProductsDetails(anyString(), any())
        val plugin = initializedPlugin()

        val result = async { runCatching { plugin.getProductsDetails("") } }
        advanceTimeBy(30.seconds - 1.milliseconds)
        runCurrent()
        assertFalse(result.isCompleted, "still waiting just before 30s")
        advanceTimeBy(1.milliseconds)
        runCurrent()
        assertTrue(result.isCompleted, "timed out at 30s")

        val error = result.await().exceptionOrNull() as FlutterError
        assertEquals("timeout", error.code)
        assertEquals("getProductsDetails", error.details)
    }

    @Test
    fun awaitSdkIgnoresACallbackAfterTheTimeout() = runTest {
        var done: Done<String>? = null
        val result = async {
            runCatching { awaitSdk("getOwnedList", INQUIRY_TIMEOUT) { done = it; true } }
        }
        advanceTimeBy(INQUIRY_TIMEOUT)
        runCurrent()
        assertEquals("timeout", (result.await().exceptionOrNull() as FlutterError).code)

        done!!(errorVo(0)) { "late" }
    }

    @Test
    fun getProductsDetailsFailsAtOnceOnANullCallback() = runTest {
        var listener: OnGetProductsDetailsListener? = null
        doAnswer { listener = it.getArgument(1); null }
            .`when`(helper).getProductsDetails(anyString(), any())
        val plugin = initializedPlugin()
        val result = async { runCatching { plugin.getProductsDetails("") } }
        runCurrent()

        OnGetProductsDetailsListener::class.java
            .getMethod("onGetProducts", ErrorVo::class.java, ArrayList::class.java)
            .invoke(listener, null, null)
        runCurrent()

        assertTrue(result.isCompleted, "failed without waiting for the timeout")
        assertIs<NullPointerException>(result.await().exceptionOrNull())
    }

    @Test
    fun awaitSdkWithoutATimeoutWaitsIndefinitely() = runTest {
        var done: Done<String>? = null
        val result = async { awaitSdk("startPayment") { done = it; true } }
        advanceTimeBy(24.hours)
        runCurrent()
        assertFalse(result.isCompleted)

        done!!(errorVo(0)) { "paid" }

        assertEquals("paid", result.await())
    }

    @Test
    fun awaitSdkMapsAFalseReturnToNotSent() = runTest {
        val error = assertFailsWith<FlutterError> { awaitSdk<Unit>("startPayment") { false } }

        assertEquals("not_sent", error.code)
        assertEquals("startPayment", error.details)
    }

    @Test
    fun awaitSdkKeepsACallbackThatArrivedBeforeAFalseReturn() = runTest {
        val value = awaitSdk("getOwnedList") { done ->
            done(errorVo(0)) { "owned" }
            false
        }

        assertEquals("owned", value)
    }
}
