package com.leapwardkoex.tamashii.widget

import android.app.Application
import android.content.Context
import android.util.Log
import com.pravera.flutter_foreground_task.FlutterForegroundTaskLifecycleListener
import com.pravera.flutter_foreground_task.FlutterForegroundTaskPlugin
import com.pravera.flutter_foreground_task.FlutterForegroundTaskStarter
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Register the same bridge in the activity, scheduled refresh and foreground service engines. */
internal fun attachWidgetBridge(context: Context, engine: FlutterEngine, finished: ((Boolean) -> Unit)? = null) {
    MethodChannel(engine.dartExecutor.binaryMessenger, "tamashii/widget").setMethodCallHandler { call, result ->
        try {
            when (call.method) {
                "hasCatalog" -> result.success(TodayWidgetHost.hasCatalog(context))
                "publishCatalog" -> {
                    TodayWidgetHost.publish(context, call.arguments as Map<*, *>)
                    result.success(null)
                }
                "pendingDownloads" -> result.success(TodayWidgetHost.pendingDownloads(context))
                "transferState" -> {
                    TodayWidgetHost.transferState(context, call.arguments as Map<*, *>)
                    result.success(null)
                }
                "serviceStopped" -> {
                    TodayWidgetHost.serviceStopped(context)
                    result.success(null)
                }
                "refreshFinished" -> {
                    result.success(null)
                    finished?.invoke(call.arguments == true)
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            Log.e("TamashiiWidget", "Widget bridge failed: ${call.method}", error)
            result.error("widget_error", error.message, null)
        }
    }
}

class TamashiiApplication : Application(), FlutterForegroundTaskLifecycleListener {
    override fun onCreate() {
        super.onCreate()
        FlutterForegroundTaskPlugin.addTaskLifecycleListener(this)
    }

    override fun onEngineCreate(flutterEngine: FlutterEngine?) {
        flutterEngine?.let { attachWidgetBridge(this, it) }
    }

    override fun onTaskStart(starter: FlutterForegroundTaskStarter) = Unit
    override fun onTaskRepeatEvent() = Unit
    override fun onTaskDestroy() = Unit
    override fun onEngineWillDestroy() = TodayWidgetHost.serviceStopped(this)
}
