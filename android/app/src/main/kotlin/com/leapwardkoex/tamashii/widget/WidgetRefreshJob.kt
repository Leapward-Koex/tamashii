package com.leapwardkoex.tamashii.widget

import android.app.job.JobParameters
import android.app.job.JobService
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import java.util.concurrent.Executors

/** App-widget updates can arrive when no activity or torrent service exists. */
class WidgetRefreshJob : JobService() {
    private val main = Handler(Looper.getMainLooper())
    private val artwork = Executors.newSingleThreadExecutor()
    private var engine: FlutterEngine? = null
    private var current: JobParameters? = null
    private val timeout = Runnable { current?.let { finish(it, retry = true) } }

    override fun onStartJob(params: JobParameters): Boolean {
        current = params
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationCompleteAsync(applicationContext, null, main) {
            if (current !== params) return@ensureInitializationCompleteAsync
            try {
                val background = FlutterEngine(applicationContext)
                engine = background
                attachWidgetBridge(applicationContext, background) { success ->
                    // Let Dart acknowledge its channel message before releasing the engine.
                    main.post {
                        if (current !== params) return@post
                        disposeEngine()
                        val rows = TodayWidgetHost.content(applicationContext).rows
                        artwork.execute {
                            try {
                                TodayWidgetArtwork.prefetch(applicationContext, rows)
                            } catch (error: RuntimeException) {
                                Log.w("TamashiiWidget", "Could not refresh widget covers", error)
                            } finally {
                                main.post {
                                    if (current === params) {
                                        TodayWidgetProvider.redraw(applicationContext)
                                        finish(params, retry = !success)
                                    }
                                }
                            }
                        }
                    }
                }
                background.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(), "package:tamashii/services/widget_catalog.dart", "refreshWidgetCatalog",
                ))
            } catch (error: Exception) {
                Log.e("TamashiiWidget", "Unable to refresh releases", error)
                finish(params, retry = true)
            }
        }
        main.postDelayed(timeout, 90_000)
        return true
    }

    private fun disposeEngine() {
        engine?.destroy()
        engine = null
    }

    private fun finish(params: JobParameters, retry: Boolean) {
        if (current !== params) return
        current = null
        main.removeCallbacks(timeout)
        disposeEngine()
        jobFinished(params, retry)
    }

    override fun onStopJob(params: JobParameters): Boolean {
        current = null
        main.removeCallbacks(timeout)
        disposeEngine()
        return true
    }

    override fun onDestroy() {
        artwork.shutdownNow()
        super.onDestroy()
    }
}
