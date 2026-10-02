package dev.studiopyro.samsung_iap_flutter

import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.util.Log
import com.samsung.android.sdk.iap.lib.constants.HelperDefine.AcknowledgedStatus
import com.samsung.android.sdk.iap.lib.constants.HelperDefine.MinorStatus
import com.samsung.android.sdk.iap.lib.constants.HelperDefine.OperationMode
import com.samsung.android.sdk.iap.lib.constants.HelperDefine.PriceChangeMode
import com.samsung.android.sdk.iap.lib.constants.HelperDefine.ProrationMode
import com.samsung.android.sdk.iap.lib.listener.OnGetOwnedListListener
import com.samsung.android.sdk.iap.lib.listener.OnGetProductsDetailsListener
import com.samsung.android.sdk.iap.lib.vo.AcknowledgeVo
import com.samsung.android.sdk.iap.lib.vo.ConsumeVo
import com.samsung.android.sdk.iap.lib.vo.ErrorVo
import com.samsung.android.sdk.iap.lib.vo.OwnedProductVo
import com.samsung.android.sdk.iap.lib.vo.ProductVo
import com.samsung.android.sdk.iap.lib.vo.PromotionEligibilityVo
import com.samsung.android.sdk.iap.lib.vo.PurchaseVo
import com.samsung.android.sdk.iap.lib.vo.SubscriptionPriceChangeVo
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.DynamicTest
import org.junit.jupiter.api.TestFactory
import org.mockito.ArgumentMatchers.any
import org.mockito.ArgumentMatchers.anyInt
import org.mockito.ArgumentMatchers.anyString
import org.mockito.ArgumentMatchers.eq
import org.mockito.ArgumentMatchers.isNull
import org.mockito.Mockito.doAnswer
import org.mockito.Mockito.mock
import org.mockito.Mockito.mockStatic
import org.mockito.Mockito.mockingDetails
import org.mockito.Mockito.never
import org.mockito.Mockito.reset
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.time.Duration.Companion.hours

@OptIn(ExperimentalCoroutinesApi::class)
class SamsungIapFlutterPluginTest : PluginTestBase() {
    private fun answerProducts(vararg replies: Pair<ErrorVo, ArrayList<ProductVo>>) {
        doAnswer { invocation ->
            val listener = invocation.getArgument<OnGetProductsDetailsListener>(1)
            replies.forEach { (error, products) -> listener.onGetProducts(error, products) }
            null
        }.`when`(helper).getProductsDetails(anyString(), any())
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

    private fun answerOwned(vararg owned: OwnedProductVo) {
        doAnswer { invocation ->
            invocation.getArgument<OnGetOwnedListListener>(1)
                .onGetOwnedProducts(errorVo(0), arrayListOf(*owned))
            true
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
        answerOwned(ownedVo(priceChange))

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
    fun getOwnedListMapsAnAbsentPriceChangeAndNullFieldsToEmpty() = runTest {
        val unparsed = mock(SubscriptionPriceChangeVo::class.java).also {
            `when`(it.isConsented()).thenReturn(null)
        }
        val broken = ownedVo(unparsed).also { `when`(it.acknowledgedStatus).thenReturn(null) }
        answerOwned(ownedVo(), broken)

        val (plain, mapped) = initializedPlugin().getOwnedList(PlatformOwnedProductFilter.ALL)

        assertEquals(null, plain.subscriptionPriceChange)
        assertEquals("", mapped.acknowledgedStatus)
        val change = mapped.subscriptionPriceChange!!
        assertEquals("", change.priceChangeMode)
        assertEquals(false, change.isConsented, "a null flag arrives as false")
        assertEquals("", change.startDate)
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

    /** [purchaseVo] as the bridge sends it. */
    private val mappedPurchase = PlatformPurchase(
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
    )

    private fun answerPayment(purchase: PurchaseVo) {
        answer(paymentCall) { paymentCall.callBack(it, errorVo(0), purchase) }
    }

    @Test
    fun startPaymentSendsTheIdsAndReturnsTheMappedPurchase() = runTest {
        answerPayment(purchaseVo())

        val purchase = initializedPlugin().startPayment("coins_100", "account", "profile")

        assertEquals(mappedPurchase, purchase)
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
    fun changeSubscriptionPlanSendsTheIdsAndReturnsTheMappedPurchase() = runTest {
        answer(planChangeCall) { planChangeCall.callBack(it, errorVo(0), purchaseVo()) }

        val purchase = initializedPlugin().changeSubscriptionPlan(
            "monthly",
            "monthly_premium",
            PlatformProrationMode.DEFERRED,
            "account",
            "profile",
        )

        assertEquals(mappedPurchase, purchase)
        verify(helper).changeSubscriptionPlan(
            eq("monthly"),
            eq("monthly_premium"),
            eq(ProrationMode.DEFERRED),
            eq("account"),
            eq("profile"),
            any(),
        )
    }

    @Test
    fun changeSubscriptionPlanMapsEveryProrationMode() = runTest {
        val expected = mapOf(
            PlatformProrationMode.INSTANT_PRORATED_DATE to ProrationMode.INSTANT_PRORATED_DATE,
            PlatformProrationMode.INSTANT_PRORATED_CHARGE to ProrationMode.INSTANT_PRORATED_CHARGE,
            PlatformProrationMode.INSTANT_NO_PRORATION to ProrationMode.INSTANT_NO_PRORATION,
            PlatformProrationMode.DEFERRED to ProrationMode.DEFERRED,
        )
        assertEquals(PlatformProrationMode.entries.toSet(), expected.keys)
        answer(planChangeCall) { planChangeCall.callBack(it, errorVo(0), purchaseVo()) }
        val plugin = initializedPlugin()

        expected.forEach { (mode, sdkMode) ->
            plugin.changeSubscriptionPlan("monthly", "monthly_premium", mode, null, null)

            verify(helper).changeSubscriptionPlan(
                eq("monthly"),
                eq("monthly_premium"),
                eq(sdkMode),
                isNull(),
                isNull(),
                any(),
            )
        }
    }

    private fun <T : ConsumeVo> ackVo(type: Class<T>, purchaseId: String?, statusCode: Int, statusString: String?): T =
        mock(type).also {
            `when`(it.purchaseId).thenReturn(purchaseId)
            `when`(it.statusCode).thenReturn(statusCode)
            `when`(it.statusString).thenReturn(statusString)
        }

    private val expectedAckResults = listOf(
        PlatformAckResult(purchaseId = "a1b2c3", statusCode = 0, statusString = "success"),
        PlatformAckResult(purchaseId = "bogus", statusCode = 1, statusString = ""),
        PlatformAckResult(purchaseId = "", statusCode = 9, statusString = "service error"),
    )

    @TestFactory
    fun ackCallsSendTheIdsAndReturnEachResult() = listOf(
        Triple(consumeCall, ConsumeVo::class.java, SamsungIapFlutterPlugin::consumePurchasedItems),
        Triple(acknowledgeCall, AcknowledgeVo::class.java, SamsungIapFlutterPlugin::acknowledgePurchases),
    ).map { (ack, vo, send) ->
        DynamicTest.dynamicTest(ack.name) {
            reset(helper)
            runTest {
                val results = arrayListOf(
                    ackVo(vo, "a1b2c3", 0, "success"),
                    ackVo(vo, "bogus", 1, null),
                    ackVo(vo, null, 9, "service error"),
                )
                answer(ack) { ack.callBack(it, errorVo(0), results) }

                assertEquals(expectedAckResults, send(initializedPlugin(), "a1b2c3,bogus"))
                val sent = mockingDetails(helper).invocations.single { it.method.name == ack.name }
                assertEquals("a1b2c3,bogus", sent.arguments.first())
            }
        }
    }

    @Test
    fun onlyAcknowledgeChecksTheGalaxyStoreVersionLikeTheSdk() = runTest {
        mockStatic(Log::class.java).use {
            for ((versionCode, sent) in mapOf(459_000_999 to false, 459_001_000 to true, 500_000_000 to true)) {
                reset(helper)
                doAnswer { true }.`when`(helper).acknowledgePurchases(anyString(), any())
                doAnswer { true }.`when`(helper).consumePurchasedItems(anyString(), any())
                val packageInfo = mock(PackageInfo::class.java).also {
                    @Suppress("DEPRECATION")
                    it.versionCode = versionCode
                }
                val packageManager = mock(PackageManager::class.java)
                `when`(packageManager.getPackageInfo(eq("com.sec.android.app.samsungapps"), anyInt()))
                    .thenReturn(packageInfo)
                val context = mock(Context::class.java)
                `when`(context.packageManager).thenReturn(packageManager)
                val plugin = SamsungIapFlutterPlugin(helperFactory = { helper }, storeStatus = { store }).apply {
                    onAttachedToEngine(binding(context))
                    initialize(PlatformOperationMode.TEST, showErrorDialog = false)
                }

                val consumed = async { runCatching { plugin.consumePurchasedItems("a1b2c3") } }
                runCurrent()
                verify(helper).consumePurchasedItems(eq("a1b2c3"), any())
                consumed.cancel()

                val result = async { runCatching { plugin.acknowledgePurchases("a1b2c3") } }
                runCurrent()

                if (sent) {
                    verify(helper).acknowledgePurchases(eq("a1b2c3"), any())
                    result.cancel()
                } else {
                    val error = result.await().exceptionOrNull() as FlutterError
                    assertEquals("store_update_required", error.code, "at version $versionCode")
                    verify(helper, never()).acknowledgePurchases(anyString(), any())
                }
            }
        }
    }

    private fun promotionVo(itemId: String?, pricing: String?, json: String?): PromotionEligibilityVo =
        mock(PromotionEligibilityVo::class.java).also {
            `when`(it.itemId).thenReturn(itemId)
            `when`(it.pricing).thenReturn(pricing)
            `when`(it.jsonString).thenReturn(json)
        }

    @Test
    fun getPromotionEligibilitySendsTheIdsAndReturnsEachResult() = runTest {
        val results = arrayListOf(
            promotionVo("monthly", "FreeTrial", """{"itemID":"monthly"}"""),
            promotionVo(null, null, null),
        )
        answer(promotionCall) { promotionCall.callBack(it, errorVo(0), results) }

        assertEquals(
            listOf(
                PlatformPromotionEligibility(itemId = "monthly", pricing = "FreeTrial", json = """{"itemID":"monthly"}"""),
                PlatformPromotionEligibility(itemId = "", pricing = "", json = ""),
            ),
            initializedPlugin().getPromotionEligibility("monthly,yearly"),
        )
        verify(helper).getPromotionEligibility(eq("monthly,yearly"), any())
    }

    @Test
    fun awaitSdkIgnoresACallbackAfterTheTimeout() = runTest {
        var done: Done<String>? = null
        val result = async {
            runCatching { awaitSdk("getOwnedList", BACKGROUND_CALL_TIMEOUT) { done = it; true } }
        }
        advanceTimeBy(BACKGROUND_CALL_TIMEOUT)
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
