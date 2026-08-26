package com.littlebit0.dailycalendar

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

object DailyAndroidWidgetBridge {
    const val CHANNEL_NAME = "daily/android_widgets"

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var channel: MethodChannel? = null

    fun register(context: Context, messenger: BinaryMessenger) {
        channel?.setMethodCallHandler(null)
        val applicationContext = context.applicationContext
        val registeredChannel = MethodChannel(messenger, CHANNEL_NAME)
        channel = registeredChannel
        registeredChannel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "updateSnapshot" -> {
                        val snapshot = call.arguments as? Map<*, *>
                            ?: throw IllegalArgumentException("A widget snapshot map is required")
                        if (!DailyAndroidWidgetStore.updateSnapshot(applicationContext, snapshot)) {
                            error("Unable to persist widget snapshot")
                        }
                        DailyWidgetUpdater.refreshAll(applicationContext)
                        result.success(null)
                    }
                    "pendingTodoActions" -> result.success(
                        DailyAndroidWidgetStore.pendingTodoActions(applicationContext),
                    )
                    "acknowledgeTodoActions" -> {
                        val arguments = call.arguments as? Map<*, *>
                        val tokens = ((arguments?.get("tokens") as? Iterable<*>)
                            ?: emptyList<Any?>())
                            .filterIsInstance<String>()
                            .filter(String::isNotBlank)
                            .toSet()
                        if (!DailyAndroidWidgetStore.acknowledgeTodoActions(
                                applicationContext,
                                tokens,
                            )
                        ) {
                            error("Unable to acknowledge widget Todo actions")
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: IllegalArgumentException) {
                result.error("invalid_widget_arguments", error.message, null)
            } catch (error: Throwable) {
                result.error("android_widget_failed", error.message, null)
            }
        }
    }

    fun unregister() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    fun notifyTodoActionsChanged() {
        mainHandler.post {
            channel?.invokeMethod("todoActionsChanged", null)
        }
    }

    fun notifyPendingTodoActions(context: Context) {
        if (DailyAndroidWidgetStore.pendingTodoActions(context).isNotEmpty()) {
            notifyTodoActionsChanged()
        }
    }
}
