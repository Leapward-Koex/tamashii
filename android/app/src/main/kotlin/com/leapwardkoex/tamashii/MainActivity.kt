package com.leapwardkoex.tamashii

import android.content.Intent
import com.leapwardkoex.tamashii.featured.FeaturedPosterFacesChannel
import com.leapwardkoex.tamashii.widget.TodayWidgetHost
import com.leapwardkoex.tamashii.widget.TodayWidgetProvider
import com.leapwardkoex.tamashii.widget.WidgetRowActivity
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
                    "takeSeriesTitle" -> {
                        val title = if (intent.action == WidgetRowActivity.OPEN_SERIES) {
                            intent.getStringExtra(WidgetRowActivity.EXTRA_TITLE).also {
                                setIntent(Intent(this, MainActivity::class.java))
                            }
                        } else null
                        result.success(title)
                    }
                    "takeDownloadSetup" -> {
                        val request = TodayWidgetHost.downloadSetup(this, intent)
                        if (intent.action == TodayWidgetHost.SETUP) setIntent(Intent(this, MainActivity::class.java))
                        result.success(request)
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
        when (intent.action) {
            WidgetRowActivity.OPEN_SERIES -> widgetSetup?.invokeMethod("seriesAvailable", null)
            TodayWidgetHost.SETUP -> widgetSetup?.invokeMethod("setupAvailable", null)
        }
    }

    override fun onDestroy() {
        widgetSetup?.setMethodCallHandler(null)
        if (::geminiNanoChannelHandler.isInitialized) {
            geminiNanoChannelHandler.dispose()
        }
        super.onDestroy()
    }
}
