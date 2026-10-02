package dev.studiopyro.samsung_iap_flutter

import android.content.Context
import com.samsung.android.sdk.iap.lib.constants.HelperDefine.AcknowledgedStatus
import com.samsung.android.sdk.iap.lib.constants.HelperDefine.MinorStatus
import com.samsung.android.sdk.iap.lib.constants.HelperDefine.OperationMode
import com.samsung.android.sdk.iap.lib.constants.HelperDefine.PriceChangeMode
import com.samsung.android.sdk.iap.lib.helper.IapHelper
import com.samsung.android.sdk.iap.lib.listener.OnGetOwnedListListener
import com.samsung.android.sdk.iap.lib.listener.OnGetProductsDetailsListener
import com.samsung.android.sdk.iap.lib.listener.OnPaymentListener
import com.samsung.android.sdk.iap.lib.vo.ErrorVo
import com.samsung.android.sdk.iap.lib.vo.OwnedProductVo
import com.samsung.android.sdk.iap.lib.vo.ProductVo
import com.samsung.android.sdk.iap.lib.vo.PurchaseVo
import com.samsung.android.sdk.iap.lib.vo.SubscriptionPriceChangeVo
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.DynamicTest
import org.junit.jupiter.api.TestFactory
import org.mockito.ArgumentMatchers.any
import org.mockito.ArgumentMatchers.anyString
import org.mockito.ArgumentMatchers.eq
import org.mockito.ArgumentMatchers.isNull
import org.mockito.Mockito.doAnswer
import org.mockito.Mockito.mock
import org.mockito.Mockito.never
import org.mockito.Mockito.reset
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertTrue
import kotlin.time.Duration
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

    private fun answerOwned(sent: Boolean = true, vararg owned: OwnedProductVo) {
        doAnswer { invocation ->
            invocation.getArgument<OnGetOwnedListListener>(1)
                .onGetOwnedProducts(errorVo(0), arrayListOf(*owned))
            sent
        }.`when`(helper).getOwnedList(anyString(), any())
    }

    private fun ownedVo(priceChange: SubscriptionPriceChangeVo? = null): OwnedProductVo =
        mock(OwnedProductVo::class.java).also {
            `when`(it.itemId).thenReturn("monthly")
            `when`(it.itemPrice).thenReturn(7.99)
            `when`(it.type).thenReturn("subscription")
            `when`(it.paymentId).thenReturn("TPMTID20260101")
            `when`(it.purchaseId).thenReturn("a1b2c3")
            `when`(it.purchaseDate).thenReturn("2026-01-01 09:00:00")
            `when`(it.subscriptionEndDate).thenReturn("2026-02-01 09:00:00")
            `when`(it.subscriptionPriceChange).thenReturn(priceChange)
            `when`(it.acknowledgedStatus).thenReturn(AcknowledgedStatus.NOT_ACKNOWLEDGED)
            `when`(it.obfuscatedAccountId).thenReturn("account")
            `when`(it.jsonString).thenReturn("""{"mItemId":"monthly"}""")
        }

    @Test
    fun getOwnedListReturnsMappedOwnedProducts() = runTest {
        val priceChange = mock(SubscriptionPriceChangeVo::class.java).also {
            `when`(it.subscriptionDurationUnit).thenReturn("MONTH")
            `when`(it.subscriptionDurationMultiplier).thenReturn("1")
            `when`(it.startDate).thenReturn("2026-06-01 00:00:00")
            `when`(it.originalLocalPrice).thenReturn(7.99)
            `when`(it.originalLocalPriceString).thenReturn("£7.99")
            `when`(it.newLocalPrice).thenReturn(8.99)
            `when`(it.newLocalPriceString).thenReturn("£8.99")
            `when`(it.isConsented()).thenReturn(true)
            `when`(it.priceChangeMode).thenReturn(PriceChangeMode.PRICE_INCREASE_USER_AGREEMENT_REQUIRED)
        }
        answerOwned(owned = arrayOf(ownedVo(priceChange)))

        val owned = initializedPlugin().getOwnedList(PlatformOwnedProductFilter.ALL).single()

        assertEquals("monthly", owned.itemId)
        assertEquals(7.99, owned.itemPrice)
        assertEquals("subscription", owned.type)
        assertEquals("TPMTID20260101", owned.paymentId)
        assertEquals("a1b2c3", owned.purchaseId)
        assertEquals("2026-01-01 09:00:00", owned.purchaseDate)
        assertEquals("2026-02-01 09:00:00", owned.subscriptionEndDate)
        assertEquals("NOT_ACKNOWLEDGED", owned.acknowledgedStatus)
        assertEquals("account", owned.obfuscatedAccountId)
        assertEquals("""{"mItemId":"monthly"}""", owned.json)
        assertEquals("", owned.obfuscatedProfileId, "null getters arrive as empty strings")
        assertEquals("", owned.itemName, "null getters arrive as empty strings")
        assertEquals(
            PlatformSubscriptionPriceChange(
                subscriptionDurationUnit = "MONTH",
                subscriptionDurationMultiplier = "1",
                startDate = "2026-06-01 00:00:00",
                originalLocalPrice = 7.99,
                originalLocalPriceString = "£7.99",
                newLocalPrice = 8.99,
                newLocalPriceString = "£8.99",
                isConsented = true,
                priceChangeMode = "PRICE_INCREASE_USER_AGREEMENT_REQUIRED",
            ),
            owned.subscriptionPriceChange,
        )
    }

    @Test
    fun getOwnedListMapsAnAbsentPriceChangeAndNullEnums() = runTest {
        val unparsed = mock(SubscriptionPriceChangeVo::class.java).also {
            `when`(it.isConsented()).thenReturn(null)
        }
        answerOwned(owned = arrayOf(ownedVo(), ownedVo(unparsed)))

        val (plain, broken) = initializedPlugin().getOwnedList(PlatformOwnedProductFilter.ALL)

        assertEquals(null, plain.subscriptionPriceChange)
        val change = broken.subscriptionPriceChange!!
        assertEquals("", change.priceChangeMode)
        assertEquals(false, change.isConsented, "a null flag arrives as false")
        assertEquals("", change.startDate)
    }

    @Test
    fun getOwnedListMapsANullAcknowledgedStatusToEmpty() = runTest {
        val vo = ownedVo().also { `when`(it.acknowledgedStatus).thenReturn(null) }
        answerOwned(owned = arrayOf(vo))

        val owned = initializedPlugin().getOwnedList(PlatformOwnedProductFilter.ALL).single()

        assertEquals("", owned.acknowledgedStatus)
    }

    @Test
    fun getOwnedListSendsEachFilterAsTheSdkProductType() = runTest {
        val expected = mapOf(
            PlatformOwnedProductFilter.ITEM to "item",
            PlatformOwnedProductFilter.SUBSCRIPTION to "subscription",
            PlatformOwnedProductFilter.ALL to "all",
        )
        assertEquals(PlatformOwnedProductFilter.entries.toSet(), expected.keys)
        answerOwned()
        val plugin = initializedPlugin()

        expected.forEach { (filter, productType) ->
            plugin.getOwnedList(filter)
            verify(helper).getOwnedList(eq(productType), any())
        }
    }

    @Test
    fun getOwnedListMapsAFalseReturnToNotSent() = runTest {
        doAnswer { false }.`when`(helper).getOwnedList(anyString(), any())

        val error = assertFailsWith<FlutterError> {
            initializedPlugin().getOwnedList(PlatformOwnedProductFilter.ALL)
        }

        assertEquals("not_sent", error.code)
        assertEquals("getOwnedList", error.details)
    }

    private fun purchaseVo(minorStatus: MinorStatus? = MinorStatus.NOT_MINOR): PurchaseVo =
        mock(PurchaseVo::class.java).also {
            `when`(it.itemId).thenReturn("coins_100")
            `when`(it.itemPrice).thenReturn(0.99)
            `when`(it.itemPriceString).thenReturn("£0.99")
            `when`(it.currencyCode).thenReturn("GBP")
            `when`(it.type).thenReturn("item")
            `when`(it.paymentId).thenReturn("TPMTID20260101")
            `when`(it.purchaseId).thenReturn("a1b2c3")
            `when`(it.orderId).thenReturn("S20260101KRA1234567")
            `when`(it.purchaseDate).thenReturn("2026-01-01 09:00:00")
            `when`(it.minorStatus).thenReturn(minorStatus)
            `when`(it.obfuscatedAccountId).thenReturn("account")
            `when`(it.jsonString).thenReturn("""{"mPurchaseId":"a1b2c3"}""")
        }

    private fun answerPayment(purchase: PurchaseVo) {
        doAnswer { invocation ->
            invocation.getArgument<OnPaymentListener>(3).onPayment(errorVo(0), purchase)
            true
        }.`when`(helper).startPayment(anyString(), any(), any(), any())
    }

    @Test
    fun startPaymentSendsTheIdsAndReturnsTheMappedPurchase() = runTest {
        answerPayment(purchaseVo())

        val purchase = initializedPlugin().startPayment("coins_100", "account", "profile")

        assertEquals(
            PlatformPurchase(
                itemId = "coins_100",
                itemName = "",
                itemPrice = 0.99,
                itemPriceString = "£0.99",
                currencyCode = "GBP",
                type = "item",
                paymentId = "TPMTID20260101",
                purchaseId = "a1b2c3",
                orderId = "S20260101KRA1234567",
                purchaseDate = "2026-01-01 09:00:00",
                minorStatus = "NOT_MINOR",
                obfuscatedAccountId = "account",
                obfuscatedProfileId = "",
                json = """{"mPurchaseId":"a1b2c3"}""",
            ),
            purchase,
        )
        verify(helper).startPayment(eq("coins_100"), eq("account"), eq("profile"), any())
    }

    @Test
    fun startPaymentPassesAbsentIdsAsNull() = runTest {
        answerPayment(purchaseVo())

        initializedPlugin().startPayment("coins_100", null, null)

        verify(helper).startPayment(eq("coins_100"), isNull(), isNull(), any())
    }

    @Test
    fun startPaymentMapsANullMinorStatusToEmpty() = runTest {
        answerPayment(purchaseVo(minorStatus = null))

        assertEquals("", initializedPlugin().startPayment("coins_100", null, null).minorStatus)
    }

    @Test
    fun startPaymentMapsAFalseReturnToNotSent() = runTest {
        doAnswer { false }.`when`(helper).startPayment(anyString(), any(), any(), any())

        val error = assertFailsWith<FlutterError> {
            initializedPlugin().startPayment("coins_100", null, null)
        }

        assertEquals("not_sent", error.code)
        assertEquals("startPayment", error.details)
    }

    /** An SDK call the plugin guards. */
    private class GuardedCall(
        val name: String,
        val listener: Class<*>,
        /** The position of the listener among the SDK method's arguments. */
        val listenerIndex: Int,
        /** What the SDK method returns once it has sent the request. */
        val sent: Any?,
        /** How long the plugin waits for the callback, or `null` for no limit. */
        val timeout: Duration?,
        /** What the SDK passes alongside an error. */
        val emptyValue: Any?,
        val call: suspend (SamsungIapFlutterPlugin) -> Any?,
        /** Calls the SDK method with matchers, for stubbing and verifying. */
        val sdk: (IapHelper) -> Unit,
    )

    private val guardedCalls = listOf(
        GuardedCall(
            "getProductsDetails",
            OnGetProductsDetailsListener::class.java,
            listenerIndex = 1,
            sent = null,
            timeout = 30.seconds,
            emptyValue = arrayListOf<ProductVo>(),
            call = { it.getProductsDetails("") },
            sdk = { it.getProductsDetails(anyString(), any()) },
        ),
        GuardedCall(
            "getOwnedList",
            OnGetOwnedListListener::class.java,
            listenerIndex = 1,
            sent = true,
            timeout = 30.seconds,
            emptyValue = arrayListOf<OwnedProductVo>(),
            call = { it.getOwnedList(PlatformOwnedProductFilter.ALL) },
            sdk = { it.getOwnedList(anyString(), any()) },
        ),
        GuardedCall(
            "startPayment",
            OnPaymentListener::class.java,
            listenerIndex = 3,
            sent = true,
            timeout = null,
            emptyValue = null,
            call = { it.startPayment("coins_100", null, null) },
            sdk = { it.startPayment(anyString(), any(), any(), any()) },
        ),
    )

    /** Stubs [guarded] to send, then hand its listener to [reply]. */
    private fun answer(guarded: GuardedCall, reply: (listener: Any) -> Unit = {}) {
        doAnswer { reply(it.getArgument(guarded.listenerIndex)); guarded.sent }
            .`when`(helper).let(guarded.sdk)
    }

    /** Calls the listener's only method, the way the SDK does. */
    private fun GuardedCall.callBack(listener: Any, error: ErrorVo?, value: Any?) {
        this.listener.methods.single().invoke(listener, error, value)
    }

    /** Fails the test unless [guarded] finishes without advancing virtual time. */
    private suspend fun TestScope.failsAtOnce(guarded: GuardedCall, error: ErrorVo?) {
        var listener: Any? = null
        answer(guarded) { listener = it }
        val result = async { runCatching { guarded.call(initializedPlugin()) } }
        runCurrent()

        guarded.callBack(listener!!, error, null)
        runCurrent()

        assertTrue(result.isCompleted, "failed without waiting for the timeout")
        assertIs<NullPointerException>(result.await().exceptionOrNull())
    }

    private val guards: Map<String, suspend TestScope.(GuardedCall) -> Unit> = mapOf(
        "fails with not_initialized before initialize" to { guarded ->
            val error = assertFailsWith<FlutterError> { guarded.call(attachedPlugin()) }

            assertEquals("not_initialized", error.code)
            verify(helper, never()).let(guarded.sdk)
        },
        "fails with not_initialized after a failed initialize" to { guarded ->
            val plugin = attachedPlugin(helperFactory = { throw IllegalStateException("no SDK") })
            assertFailsWith<IllegalStateException> {
                plugin.initialize(PlatformOperationMode.TEST, showErrorDialog = true)
            }

            val error = assertFailsWith<FlutterError> { guarded.call(plugin) }

            assertEquals("not_initialized", error.code)
        },
        "fails with store_unavailable before the SDK" to { guarded ->
            store = PlatformStoreStatus.INVALID

            val error = assertFailsWith<FlutterError> { guarded.call(initializedPlugin()) }

            assertEquals("store_unavailable", error.code)
            assertEquals("invalid", error.details)
            verify(helper, never()).let(guarded.sdk)
        },
        "times out only at its limit" to { guarded ->
            answer(guarded)
            val plugin = initializedPlugin()
            val timeout = guarded.timeout

            val result = async { runCatching { guarded.call(plugin) } }
            if (timeout == null) {
                advanceTimeBy(24.hours)
                runCurrent()
                assertFalse(result.isCompleted, "still waiting after 24h")
                result.cancel()
            } else {
                advanceTimeBy(timeout - 1.milliseconds)
                runCurrent()
                assertFalse(result.isCompleted, "still waiting just before $timeout")
                advanceTimeBy(1.milliseconds)
                runCurrent()
                assertTrue(result.isCompleted, "timed out at $timeout")

                val error = result.await().exceptionOrNull() as FlutterError
                assertEquals("timeout", error.code)
                assertEquals(guarded.name, error.details)
            }
        },
        "throws the SDK error" to { guarded ->
            answer(guarded) { guarded.callBack(it, errorVo(-1005), guarded.emptyValue) }

            val error = assertFailsWith<FlutterError> { guarded.call(initializedPlugin()) }

            assertEquals("sdk", error.code)
            assertEquals("Product does not exist.", error.message)
            assertEquals(
                mapOf("errorCode" to -1005, "errorDetails" to "IS9207/6050/x", "dialogShown" to true),
                error.details,
            )
        },
        "fails at once on a success with a null value" to { guarded ->
            failsAtOnce(guarded, errorVo(0))
        },
        "fails at once on a null error and value" to { guarded ->
            failsAtOnce(guarded, null)
        },
    )

    @TestFactory
    fun guardedSdkCalls() = guardedCalls.flatMap { guarded ->
        guards.map { (case, check) ->
            DynamicTest.dynamicTest("${guarded.name} $case") {
                reset(helper)
                store = PlatformStoreStatus.AVAILABLE
                runTest { check(guarded) }
            }
        }
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
