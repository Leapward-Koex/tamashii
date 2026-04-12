package com.leapwardkoex.tamashii

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private lateinit var geminiNanoChannelHandler: GeminiNanoMethodChannelHandler

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        geminiNanoChannelHandler = GeminiNanoMethodChannelHandler(this)
        geminiNanoChannelHandler.configure(flutterEngine)
    }

    override fun onDestroy() {
        if (::geminiNanoChannelHandler.isInitialized) {
            geminiNanoChannelHandler.dispose()
        }
        super.onDestroy()
    }
}
