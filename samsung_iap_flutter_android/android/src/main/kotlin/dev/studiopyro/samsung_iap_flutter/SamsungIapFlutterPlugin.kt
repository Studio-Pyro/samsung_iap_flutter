package dev.studiopyro.samsung_iap_flutter

import android.content.Context
import com.samsung.android.sdk.iap.lib.constants.HelperDefine
import com.samsung.android.sdk.iap.lib.helper.IapHelper
import com.samsung.android.sdk.iap.lib.util.HelperUtil
import com.samsung.android.sdk.iap.lib.vo.ErrorVo
import com.samsung.android.sdk.iap.lib.vo.ProductVo
import io.flutter.embedding.engine.plugins.FlutterPlugin
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.suspendCancellableCoroutine

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

    // getProductsDetails never calls back when Galaxy Store is unusable, so
    // the store is checked first.
    override suspend fun getProductsDetails(productIds: String): List<PlatformProduct> {
        val helper = requireHelper()
        requireStore()
        return call("getProductsDetails") { done ->
            helper.getProductsDetails(productIds) { error, products ->
                done(error) { products.map { it.toPlatform() } }
            }
            true
        }
    }

    private fun requireHelper(): IapHelper =
        helper ?: throw FlutterError("not_initialized", "Call initialize first.")

    private fun requireStore() {
        val status = storeStatus(context)
        if (status != PlatformStoreStatus.AVAILABLE) {
            throw FlutterError("store_unavailable", "Galaxy Store is unusable: $status", status.name)
        }
    }
}

/** Delivers one SDK callback: its error, and the value to compute on success. */
internal typealias Done<T> = (error: ErrorVo, value: () -> T) -> Unit

/**
 * Bridges one SDK call to one suspend result.
 *
 * [start] invokes the SDK and returns what it returned. A `false` return means
 * the SDK will never call back. Only the first callback counts, including one
 * that arrives before [start] returns.
 */
internal suspend fun <T> call(name: String, start: (Done<T>) -> Boolean): T =
    suspendCancellableCoroutine { continuation ->
        val finished = AtomicBoolean(false)
        fun finish(result: Result<T>) {
            if (finished.compareAndSet(false, true)) continuation.resumeWith(result)
        }
        val sent = start { error, value ->
            finish(
                if (error.errorCode == HelperDefine.IAP_ERROR_NONE) {
                    runCatching(value)
                } else {
                    Result.failure(error.toFlutterError())
                },
            )
        }
        if (!sent) finish(Result.failure(FlutterError("not_sent", "$name was not sent.", name)))
    }

internal fun galaxyStoreStatus(context: Context): PlatformStoreStatus = when {
    !HelperUtil.isInstalledAppsPackage(context) -> PlatformStoreStatus.NOT_INSTALLED
    !HelperUtil.isEnabledAppsPackage(context) -> PlatformStoreStatus.DISABLED
    !HelperUtil.isValidAppsPackage(context) -> PlatformStoreStatus.INVALID
    else -> PlatformStoreStatus.AVAILABLE
}

private fun PlatformOperationMode.toSdk(): HelperDefine.OperationMode = when (this) {
    PlatformOperationMode.PRODUCTION -> HelperDefine.OperationMode.OPERATION_MODE_PRODUCTION
    PlatformOperationMode.TEST -> HelperDefine.OperationMode.OPERATION_MODE_TEST
    PlatformOperationMode.TEST_FAILURE -> HelperDefine.OperationMode.OPERATION_MODE_TEST_FAILURE
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
