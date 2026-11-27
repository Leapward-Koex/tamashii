package com.leapwardkoex.tamashii

import android.content.Intent
import com.leapwardkoex.tamashii.featured.FeaturedPosterFacesChannel
import com.leapwardkoex.tamashii.widget.TodayWidgetHost
import com.leapwardkoex.tamashii.widget.TodayWidgetProvider
import com.leapwardkoex.tamashii.widget.attachWidgetBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var geminiNanoChannelHandler: GeminiNanoMethodChannelHandler
    private var widgetSetup: MethodChannel? = null
    private var featuredPosterFaces: FeaturedPosterFacesChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        featuredPosterFaces = FeaturedPosterFacesChannel(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        attachWidgetBridge(applicationContext, flutterEngine)
        widgetSetup = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tamashii/widget_setup").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeSetupTitle" -> {
                        val title = TodayWidgetHost.setupTitle(this, intent)
                        if (intent.action == TodayWidgetHost.SETUP) setIntent(Intent(this, MainActivity::class.java))
                        result.success(title)
                    }
                    "redraw" -> {
                        TodayWidgetProvider.redraw(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        geminiNanoChannelHandler = GeminiNanoMethodChannelHandler(this)
        geminiNanoChannelHandler.configure(flutterEngine)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        featuredPosterFaces?.close()
        featuredPosterFaces = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == TodayWidgetHost.SETUP) widgetSetup?.invokeMethod("setupAvailable", null)
    }

    override fun onDestroy() {
        widgetSetup?.setMethodCallHandler(null)
        if (::geminiNanoChannelHandler.isInitialized) {
            geminiNanoChannelHandler.dispose()
        }
        super.onDestroy()
    }
}
