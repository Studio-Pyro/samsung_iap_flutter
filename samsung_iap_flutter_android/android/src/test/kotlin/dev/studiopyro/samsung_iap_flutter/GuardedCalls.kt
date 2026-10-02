package dev.studiopyro.samsung_iap_flutter

import com.samsung.android.sdk.iap.lib.helper.IapHelper
import com.samsung.android.sdk.iap.lib.listener.OnAcknowledgePurchasesListener
import com.samsung.android.sdk.iap.lib.listener.OnChangeSubscriptionPlanListener
import com.samsung.android.sdk.iap.lib.listener.OnConsumePurchasedItemsListener
import com.samsung.android.sdk.iap.lib.listener.OnGetOwnedListListener
import com.samsung.android.sdk.iap.lib.listener.OnGetProductsDetailsListener
import com.samsung.android.sdk.iap.lib.listener.OnGetPromotionEligibilityListener
import com.samsung.android.sdk.iap.lib.listener.OnPaymentListener
import org.mockito.ArgumentMatchers.any
import org.mockito.ArgumentMatchers.anyString

/** An SDK call the plugin guards. The SDK takes its listener last. */
class GuardedCall(
    val name: String,
    val listener: Class<*>,
    /** What the SDK method returns once it has sent the request. */
    val sent: Any?,
    val call: suspend (SamsungIapFlutterPlugin) -> Any?,
    /** Calls the SDK method with matchers, for stubbing and verifying. */
    val sdk: (IapHelper) -> Unit,
)

val productsCall = GuardedCall(
    "getProductsDetails",
    OnGetProductsDetailsListener::class.java,
    sent = null,
    call = { it.getProductsDetails("") },
    sdk = { it.getProductsDetails(anyString(), any()) },
)

val ownedCall = GuardedCall(
    "getOwnedList",
    OnGetOwnedListListener::class.java,
    sent = true,
    call = { it.getOwnedList(PlatformOwnedProductFilter.ALL) },
    sdk = { it.getOwnedList(anyString(), any()) },
)

val promotionCall = GuardedCall(
    "getPromotionEligibility",
    OnGetPromotionEligibilityListener::class.java,
    sent = true,
    call = { it.getPromotionEligibility("monthly") },
    sdk = { it.getPromotionEligibility(anyString(), any()) },
)

val inquiryCalls = listOf(productsCall, ownedCall, promotionCall)

val consumeCall = GuardedCall(
    "consumePurchasedItems",
    OnConsumePurchasedItemsListener::class.java,
    sent = true,
    call = { it.consumePurchasedItems("a1b2c3") },
    sdk = { it.consumePurchasedItems(anyString(), any()) },
)

val acknowledgeCall = GuardedCall(
    "acknowledgePurchases",
    OnAcknowledgePurchasesListener::class.java,
    sent = true,
    call = { it.acknowledgePurchases("a1b2c3") },
    sdk = { it.acknowledgePurchases(anyString(), any()) },
)

/** Consume and acknowledge, which the SDK runs in the background like inquiries. */
val ackCalls = listOf(consumeCall, acknowledgeCall)

val paymentCall = GuardedCall(
    "startPayment",
    OnPaymentListener::class.java,
    sent = true,
    call = { it.startPayment("coins_100", null, null) },
    sdk = { it.startPayment(anyString(), any(), any(), any()) },
)

val planChangeCall = GuardedCall(
    "changeSubscriptionPlan",
    OnChangeSubscriptionPlanListener::class.java,
    sent = true,
    call = {
        it.changeSubscriptionPlan("monthly", "monthly_premium", PlatformProrationMode.INSTANT_PRORATED_DATE, null, null)
    },
    sdk = { it.changeSubscriptionPlan(anyString(), anyString(), any(), any(), any(), any()) },
)

/** Calls that show Samsung's payment UI and wait as long as the user does. */
val paymentCalls = listOf(paymentCall, planChangeCall)
