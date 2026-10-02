package dev.studiopyro.samsung_iap_flutter

import com.samsung.android.sdk.iap.lib.vo.ErrorVo
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.DynamicTest
import org.junit.jupiter.api.TestFactory
import org.mockito.Mockito.doAnswer
import org.mockito.Mockito.never
import org.mockito.Mockito.reset
import org.mockito.Mockito.verify
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import kotlin.time.Duration.Companion.hours
import kotlin.time.Duration.Companion.milliseconds

@OptIn(ExperimentalCoroutinesApi::class)
class GuardedSdkCallsTest : PluginTestBase() {
    /** Fails the test unless [guarded] finishes without advancing virtual time. */
    private suspend fun TestScope.failsAtOnce(guarded: GuardedCall, error: ErrorVo?) {
        var listener: Any? = null
        answer(guarded) { listener = it }
        val result = async { runCatching { guarded.call(initializedPlugin()) } }
        runCurrent()

        guarded.callBack(listener!!, error, null)
        runCurrent()

        assertTrue(result.isCompleted, "failed without waiting for the timeout")
        assertTrue(result.await().isFailure)
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
        "throws the SDK error" to { guarded ->
            answer(guarded) { guarded.callBack(it, errorVo(-1005), null) }

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
    fun guardedSdkCalls() = (inquiryCalls + ackCalls + paymentCalls).flatMap { guarded ->
        guards.map { (case, check) ->
            DynamicTest.dynamicTest("${guarded.name} $case") {
                reset(helper)
                store = PlatformStoreStatus.AVAILABLE
                runTest { check(guarded) }
            }
        }
    }

    @TestFactory
    fun backgroundCallsTimeOutAfter30Seconds() = (inquiryCalls + ackCalls).map { guarded ->
        DynamicTest.dynamicTest(guarded.name) {
            reset(helper)
            runTest {
                answer(guarded)
                val plugin = initializedPlugin()

                val result = async { runCatching { guarded.call(plugin) } }
                advanceTimeBy(BACKGROUND_CALL_TIMEOUT - 1.milliseconds)
                runCurrent()
                assertFalse(result.isCompleted, "still waiting just before 30s")
                advanceTimeBy(1.milliseconds)
                runCurrent()
                assertTrue(result.isCompleted, "timed out at 30s")

                val error = result.await().exceptionOrNull() as FlutterError
                assertEquals("timeout", error.code)
                assertEquals(guarded.name, error.details)
            }
        }
    }

    @TestFactory
    fun paymentsStillWaitAfter24Hours() = paymentCalls.map { guarded ->
        DynamicTest.dynamicTest(guarded.name) {
            reset(helper)
            runTest {
                answer(guarded)
                val plugin = initializedPlugin()

                val result = async { guarded.call(plugin) }
                advanceTimeBy(24.hours)
                runCurrent()

                assertFalse(result.isCompleted, "still waiting after 24h")
                result.cancel()
            }
        }
    }

    @TestFactory
    fun paymentsReportASuccessWithoutAPurchaseAsResultUnknown() = paymentCalls.flatMap { guarded ->
        listOf("a success" to errorVo(0), "no error" to null).map { (case, error) ->
            DynamicTest.dynamicTest("${guarded.name} with $case") {
                reset(helper)
                answer(guarded) { guarded.callBack(it, error, null) }

                val failure = runCatching { runTest { guarded.call(initializedPlugin()) } }
                    .exceptionOrNull() as FlutterError

                assertEquals("result_unknown", failure.code)
                assertEquals(guarded.name, failure.details)
            }
        }
    }

    @TestFactory
    fun paymentsMapAFalseReturnToNotSent() = paymentCalls.map { guarded ->
        DynamicTest.dynamicTest(guarded.name) {
            reset(helper)
            doAnswer { false }.`when`(helper).let(guarded.sdk)

            val error = runCatching { runTest { guarded.call(initializedPlugin()) } }
                .exceptionOrNull() as FlutterError

            assertEquals("not_sent", error.code)
            assertEquals(guarded.name, error.details)
        }
    }
}
