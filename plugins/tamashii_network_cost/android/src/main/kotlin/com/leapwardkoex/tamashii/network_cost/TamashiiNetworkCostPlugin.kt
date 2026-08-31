package com.leapwardkoex.tamashii.network_cost

import android.content.Context
import android.net.ConnectivityManager
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Android network-cost adapter. Flutter auto-registers one instance per engine. */
class TamashiiNetworkCostPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {
    companion object {
        private const val METHODS_CHANNEL =
            "com.leapwardkoex.tamashii/network_cost/methods"
        private const val EVENTS_CHANNEL =
            "com.leapwardkoex.tamashii/network_cost/status_events"
    }

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var monitor: NetworkStatusMonitor
    private lateinit var mainHandler: Handler
    private var eventSink: EventChannel.EventSink? = null
    private var streamGeneration = 0L

    @Volatile
    private var attached = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val manager = binding.applicationContext.getSystemService(
            Context.CONNECTIVITY_SERVICE,
        ) as ConnectivityManager
        monitor = NetworkStatusMonitor(AndroidNetworkStateSource(manager))
        mainHandler = Handler(Looper.getMainLooper())
        methodChannel = MethodChannel(binding.binaryMessenger, METHODS_CHANNEL)
        eventChannel = EventChannel(binding.binaryMessenger, EVENTS_CHANNEL)
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
        attached = true
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        attached = false
        streamGeneration += 1
        monitor.stop()
        eventSink = null
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "currentNetworkStatus" -> result.success(monitor.current().toWireValue())
            // Retained for clients compiled against the original private API.
            "currentNetworkCost" -> result.success(monitor.current().cost.wireValue)
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        streamGeneration += 1
        val generation = streamGeneration
        eventSink = events
        monitor.start { status ->
            mainHandler.post {
                if (
                    attached &&
                    streamGeneration == generation &&
                    eventSink === events
                ) {
                    events.success(status.toWireValue())
                }
            }
        }
    }

    override fun onCancel(arguments: Any?) {
        streamGeneration += 1
        eventSink = null
        monitor.stop()
    }
}
