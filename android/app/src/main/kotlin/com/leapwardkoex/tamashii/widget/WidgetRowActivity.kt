package com.leapwardkoex.tamashii.widget

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import com.leapwardkoex.tamashii.MainActivity

/** Android collection widgets share one pending-intent template for the row and its download button. */
class WidgetRowActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        when (intent.action) {
            OPEN_SERIES -> {
                val title = intent.getStringExtra(EXTRA_TITLE)
                if (!title.isNullOrBlank()) {
                    startActivity(Intent(this, MainActivity::class.java)
                        .setAction(OPEN_SERIES)
                        .putExtra(EXTRA_TITLE, title)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP))
                }
            }
            TodayWidgetProvider.ACTION_DOWNLOAD ->
                TodayWidgetProvider.downloadFromIntent(this, intent)?.let { startActivity(it) }
        }
        finish()
    }

    companion object {
        const val OPEN_SERIES = "com.leapwardkoex.tamashii.widget.OPEN_SERIES"
        const val EXTRA_TITLE = "seriesTitle"
    }
}
