package dev.studiopyro.samsung_iap_flutter

import android.content.Context
import com.samsung.android.sdk.iap.lib.constants.HelperDefine
import com.samsung.android.sdk.iap.lib.helper.IapHelper
import com.samsung.android.sdk.iap.lib.util.HelperUtil
import com.samsung.android.sdk.iap.lib.vo.ErrorVo
import com.samsung.android.sdk.iap.lib.vo.OwnedProductVo
import com.samsung.android.sdk.iap.lib.vo.ProductVo
import com.samsung.android.sdk.iap.lib.vo.PurchaseVo
import com.samsung.android.sdk.iap.lib.vo.SubscriptionPriceChangeVo
import io.flutter.embedding.engine.plugins.FlutterPlugin
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.time.Duration
import kotlin.time.Duration.Companion.seconds
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeout

/** How long an inquiry waits for Samsung. Payments wait indefinitely. */
internal val INQUIRY_TIMEOUT = 30.seconds

class SamsungIapFlutterPlugin(
    private val helperFactory: (Context) -> IapHelper = IapHelper::getInstance,
    private val storeStatus: (Context) -> PlatformStoreStatus = ::galaxyStoreStatus,
) : FlutterPlugin, SamsungIapHostApi {
    private lateinit var context: Context
    private var helper: IapHelper? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        SamsungIapHostApi.setUp(binding.binaryMessenger, this)
    }

    // IapHelper 6.5.2 has no dispose().
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        SamsungIapHostApi.setUp(binding.binaryMessenger, null)
    }

    override fun initialize(mode: PlatformOperationMode, showErrorDialog: Boolean) {
        helper = helperFactory(context).apply {
            setOperationMode(mode.toSdk())
            setShowErrorDialog(showErrorDialog)
        }
    }

    override fun getStoreStatus(): PlatformStoreStatus = storeStatus(context)

    override suspend fun getProductsDetails(productIds: String): List<PlatformProduct> {
        val helper = requireHelper()
        requireStore()
        return awaitSdk("getProductsDetails", INQUIRY_TIMEOUT) { done ->
            helper.getProductsDetails(productIds) { error: ErrorVo?, products: ArrayList<ProductVo>? ->
                done(error) { products!!.map { it.toPlatform() } }
            }
            true
        }
    }

    override suspend fun getOwnedList(filter: PlatformOwnedProductFilter): List<PlatformOwnedProduct> {
        val helper = requireHelper()
        requireStore()
        return awaitSdk("getOwnedList", INQUIRY_TIMEOUT) { done ->
            helper.getOwnedList(filter.toSdk()) { error: ErrorVo?, owned: ArrayList<OwnedProductVo>? ->
                done(error) { owned!!.map { it.toPlatform() } }
            }
        }
    }

    override suspend fun startPayment(
        itemId: String,
        obfuscatedAccountId: String?,
        obfuscatedProfileId: String?,
    ): PlatformPurchase {
        val helper = requireHelper()
        requireStore()
        return awaitSdk("startPayment") { done ->
            helper.startPayment(itemId, obfuscatedAccountId, obfuscatedProfileId) { error: ErrorVo?, purchase: PurchaseVo? ->
                done(error) { purchase!!.toPlatform() }
            }
        }
    }

    private fun requireHelper(): IapHelper =
        helper ?: throw FlutterError("not_initialized", "Call initialize first.")

    /**
     * Fails unless Galaxy Store is usable. Every SDK call checks this first:
     * without it, `getProductsDetails` never calls back, and `startPayment`
     * shows Samsung's own install, enable or update dialog.
     */
    private fun requireStore() {
        val status = storeStatus(context)
        if (status != PlatformStoreStatus.AVAILABLE) {
            val name = status.publicName
            throw FlutterError("store_unavailable", "Galaxy Store is unusable: $name", name)
        }
    }
}

/** Delivers one SDK callback: its error, and the value to compute on success. */
internal typealias Done<T> = (error: ErrorVo?, value: () -> T) -> Unit

/**
 * Bridges one SDK call to one suspend result.
 *
 * [start] invokes the SDK and returns what it returned. A `false` return means
 * the SDK will never call back. Only the first callback counts, including one
 * that arrives before [start] returns. With a [timeout], an unanswered call
 * fails with `timeout` and a later callback is ignored.
 */
internal suspend fun <T> awaitSdk(
    name: String,
    timeout: Duration? = null,
    start: (Done<T>) -> Boolean,
): T {
    val await = suspend {
        suspendCancellableCoroutine<T> { continuation ->
            val finished = AtomicBoolean(false)
            fun finish(result: () -> Result<T>) {
                if (finished.compareAndSet(false, true)) continuation.resumeWith(result())
            }
            val sent = start { error, value ->
                finish {
                    runCatching {
                        if (error != null && error.errorCode != HelperDefine.IAP_ERROR_NONE) {
                            throw error.toFlutterError()
                        }
                        value()
                    }
                }
            }
            if (!sent) finish { Result.failure(FlutterError("not_sent", "$name was not sent.", name)) }
        }
    }
    if (timeout == null) return await()
    return try {
        withTimeout(timeout) { await() }
    } catch (_: TimeoutCancellationException) {
        throw FlutterError(
            "timeout",
            "$name got no answer from Samsung within ${timeout.inWholeSeconds}s.",
            name,
        )
    }
}

internal fun galaxyStoreStatus(context: Context): PlatformStoreStatus = when {
    !HelperUtil.isInstalledAppsPackage(context) -> PlatformStoreStatus.NOT_INSTALLED
    !HelperUtil.isEnabledAppsPackage(context) -> PlatformStoreStatus.DISABLED
    !HelperUtil.isValidAppsPackage(context) -> PlatformStoreStatus.INVALID
    else -> PlatformStoreStatus.AVAILABLE
}

/** The name of the matching public `GalaxyStoreStatus`. */
private val PlatformStoreStatus.publicName: String
    get() = when (this) {
        PlatformStoreStatus.AVAILABLE -> "available"
        PlatformStoreStatus.NOT_INSTALLED -> "notInstalled"
        PlatformStoreStatus.DISABLED -> "disabled"
        PlatformStoreStatus.INVALID -> "invalid"
    }

private fun PlatformOperationMode.toSdk(): HelperDefine.OperationMode = when (this) {
    PlatformOperationMode.PRODUCTION -> HelperDefine.OperationMode.OPERATION_MODE_PRODUCTION
    PlatformOperationMode.TEST -> HelperDefine.OperationMode.OPERATION_MODE_TEST
    PlatformOperationMode.TEST_FAILURE -> HelperDefine.OperationMode.OPERATION_MODE_TEST_FAILURE
}

private fun PlatformOwnedProductFilter.toSdk(): String = when (this) {
    PlatformOwnedProductFilter.ITEM -> HelperDefine.PRODUCT_TYPE_ITEM
    PlatformOwnedProductFilter.SUBSCRIPTION -> HelperDefine.PRODUCT_TYPE_SUBSCRIPTION
    PlatformOwnedProductFilter.ALL -> HelperDefine.PRODUCT_TYPE_ALL
}

private fun ErrorVo.toFlutterError() = FlutterError(
    "sdk",
    errorString,
    mapOf(
        "errorCode" to errorCode,
        "errorDetails" to errorDetailsString,
        "dialogShown" to isShowDialog,
    ),
)

private fun ProductVo.toPlatform() = PlatformProduct(
    itemId = itemId.orEmpty(),
    itemName = itemName.orEmpty(),
    itemPrice = itemPrice,
    itemPriceString = itemPriceString.orEmpty(),
    currencyUnit = currencyUnit.orEmpty(),
    currencyCode = currencyCode.orEmpty(),
    itemDesc = itemDesc.orEmpty(),
    type = type.orEmpty(),
    subscriptionDurationUnit = subscriptionDurationUnit.orEmpty(),
    subscriptionDurationMultiplier = subscriptionDurationMultiplier.orEmpty(),
    tieredSubscriptionYN = tieredSubscriptionYN.orEmpty(),
    tieredPrice = tieredPrice.orEmpty(),
    tieredPriceString = tieredPriceString.orEmpty(),
    tieredSubscriptionDurationUnit = tieredSubscriptionDurationUnit.orEmpty(),
    tieredSubscriptionDurationMultiplier = tieredSubscriptionDurationMultiplier.orEmpty(),
    tieredSubscriptionCount = tieredSubscriptionCount.orEmpty(),
    showStartDate = showStartDate.orEmpty(),
    showEndDate = showEndDate.orEmpty(),
    itemImageUrl = itemImageUrl.orEmpty(),
    itemDownloadUrl = itemDownloadUrl.orEmpty(),
    freeTrialPeriod = freeTrialPeriod.orEmpty(),
    json = jsonString.orEmpty(),
)

private fun OwnedProductVo.toPlatform() = PlatformOwnedProduct(
    itemId = itemId.orEmpty(),
    itemName = itemName.orEmpty(),
    itemPrice = itemPrice,
    itemPriceString = itemPriceString.orEmpty(),
    currencyCode = currencyCode.orEmpty(),
    type = type.orEmpty(),
    paymentId = paymentId.orEmpty(),
    purchaseId = purchaseId.orEmpty(),
    purchaseDate = purchaseDate.orEmpty(),
    subscriptionEndDate = subscriptionEndDate.orEmpty(),
    subscriptionPriceChange = subscriptionPriceChange?.toPlatform(),
    acknowledgedStatus = acknowledgedStatus?.name.orEmpty(),
    obfuscatedAccountId = obfuscatedAccountId.orEmpty(),
    obfuscatedProfileId = obfuscatedProfileId.orEmpty(),
    json = jsonString.orEmpty(),
)

private fun PurchaseVo.toPlatform() = PlatformPurchase(
    itemId = itemId.orEmpty(),
    itemName = itemName.orEmpty(),
    itemPrice = itemPrice,
    itemPriceString = itemPriceString.orEmpty(),
    currencyCode = currencyCode.orEmpty(),
    type = type.orEmpty(),
    paymentId = paymentId.orEmpty(),
    purchaseId = purchaseId.orEmpty(),
    orderId = orderId.orEmpty(),
    purchaseDate = purchaseDate.orEmpty(),
    minorStatus = minorStatus?.name.orEmpty(),
    obfuscatedAccountId = obfuscatedAccountId.orEmpty(),
    obfuscatedProfileId = obfuscatedProfileId.orEmpty(),
    json = jsonString.orEmpty(),
)

private fun SubscriptionPriceChangeVo.toPlatform() = PlatformSubscriptionPriceChange(
    subscriptionDurationUnit = subscriptionDurationUnit.orEmpty(),
    subscriptionDurationMultiplier = subscriptionDurationMultiplier.orEmpty(),
    startDate = startDate.orEmpty(),
    originalLocalPrice = originalLocalPrice,
    originalLocalPriceString = originalLocalPriceString.orEmpty(),
    newLocalPrice = newLocalPrice,
    newLocalPriceString = newLocalPriceString.orEmpty(),
    isConsented = isConsented() == true,
    priceChangeMode = priceChangeMode?.name.orEmpty(),
)
