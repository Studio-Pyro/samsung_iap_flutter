package dev.studiopyro.samsung_iap_flutter

import android.content.Context
import com.samsung.android.sdk.iap.lib.helper.IapHelper
import com.samsung.android.sdk.iap.lib.vo.ErrorVo
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import org.mockito.Mockito.doAnswer
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`

/** A mock [IapHelper] and Galaxy Store, and the plugin attached to them. */
abstract class PluginTestBase {
    protected val helper: IapHelper = mock(IapHelper::class.java)
    protected var store = PlatformStoreStatus.AVAILABLE

    protected fun binding(context: Context = mock(Context::class.java)): FlutterPlugin.FlutterPluginBinding =
        mock(FlutterPlugin.FlutterPluginBinding::class.java).also {
            `when`(it.applicationContext).thenReturn(context)
            `when`(it.binaryMessenger).thenReturn(mock(BinaryMessenger::class.java))
        }

    /**
     * Passes every Galaxy Store version check. The SDK's own check reads a real
     * Context, so it has its own test.
     */
    protected fun attachedPlugin(
        helperFactory: (Context) -> IapHelper = { helper },
    ): SamsungIapFlutterPlugin = SamsungIapFlutterPlugin(
        helperFactory = helperFactory,
        storeStatus = { store },
        acknowledgeAvailable = { true },
    ).apply { onAttachedToEngine(binding()) }

    protected fun initializedPlugin() =
        attachedPlugin().apply { initialize(PlatformOperationMode.TEST, showErrorDialog = false) }

    protected fun errorVo(code: Int): ErrorVo = mock(ErrorVo::class.java).also {
        `when`(it.errorCode).thenReturn(code)
        `when`(it.errorString).thenReturn("Product does not exist.")
        `when`(it.errorDetailsString).thenReturn("IS9207/6050/x")
        `when`(it.isShowDialog).thenReturn(true)
    }

    /** Stubs [guarded] to send, then hand its listener to [reply]. */
    protected fun answer(guarded: GuardedCall, reply: (listener: Any) -> Unit = {}) {
        doAnswer { reply(it.arguments.last()); guarded.sent }.`when`(helper).let(guarded.sdk)
    }

    /** Calls the listener's only method, the way the SDK does. */
    protected fun GuardedCall.callBack(listener: Any, error: ErrorVo?, value: Any?) {
        this.listener.methods.single().invoke(listener, error, value)
    }
}
