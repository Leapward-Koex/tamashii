package com.leapwardkoex.tamashii.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.text.format.DateFormat
import android.util.SizeF
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import com.leapwardkoex.tamashii.MainActivity
import com.leapwardkoex.tamashii.R
import java.text.NumberFormat
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.UUID

class TodayWidgetProvider : AppWidgetProvider() {
    override fun onEnabled(context: Context) = TodayWidgetHost.onEnabled(context)
    override fun onDisabled(context: Context) = TodayWidgetHost.onDisabled(context)

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        TodayWidgetHost.onEnabled(context)
        update(context, manager, ids)
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        update(context, manager, intArrayOf(id))
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_DOWNLOAD -> downloadFromIntent(context, intent)
            Intent.ACTION_DATE_CHANGED, Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_LOCALE_CHANGED -> {
                if (widgetIds(context).isNotEmpty()) {
                    TodayWidgetHost.onEnabled(context)
                    redraw(context)
                }
            }
            else -> super.onReceive(context, intent)
        }
    }

    companion object {
        internal const val ACTION_DOWNLOAD = "com.leapwardkoex.tamashii.widget.DOWNLOAD"
        private const val EXTRA_KEY = "episodeKey"
        private const val EXTRA_DATE = "date"
        // Android selects the largest size that fits each live host surface, including after rotation.
        internal const val INBOX_HEIGHT_DP = 240f

        private fun widgetIds(context: Context): IntArray =
            AppWidgetManager.getInstance(context).getAppWidgetIds(ComponentName(context, TodayWidgetProvider::class.java))

        fun redraw(context: Context) = update(context, AppWidgetManager.getInstance(context), widgetIds(context))

        internal fun downloadFromIntent(context: Context, intent: Intent): Intent? {
            val key = intent.getStringExtra(EXTRA_KEY)
            val date = intent.getStringExtra(EXTRA_DATE)?.let { runCatching { LocalDate.parse(it) }.getOrNull() }
            // A stale launcher row may still be visible after midnight or a bookmark edit.
            if (key != null && date != null && date == LocalDate.now()) {
                return TodayWidgetHost.onDownload(context, key, date)
            }
            redraw(context)
            return null
        }

        private fun update(context: Context, manager: AppWidgetManager, ids: IntArray) {
            if (ids.isEmpty()) return
            manager.updateAppWidget(ids, responsive(context, TodayWidgetHost.content(context)))
        }

        internal fun responsive(context: Context, content: TodayWidgetContent): RemoteViews =
            RemoteViews(mapOf(
                SizeF(1f, 1f) to render(context, content, tall = false),
                SizeF(1f, INBOX_HEIGHT_DP) to render(context, content, tall = true),
            ))

        internal fun render(context: Context, content: TodayWidgetContent, tall: Boolean): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.today_widget)
            val locale = context.resources.configuration.locales[0]
            val datePattern = DateFormat.getBestDateTimePattern(locale, "EEEEMMMd")
            val date = content.date.format(DateTimeFormatter.ofPattern(datePattern, locale))
            val title = if (tall) context.getString(R.string.today_widget_title) else date
            views.setTextViewText(R.id.widget_title, title)
            views.setImageViewResource(R.id.widget_icon, if (tall) R.drawable.widget_inbox else R.drawable.widget_calendar)
            val openApp = Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            val open = PendingIntent.getActivity(context, 0, openApp, PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_open, open)
            views.setContentDescription(R.id.widget_open, "$title. ${context.getString(R.string.today_widget_open)}")
            views.setOnClickPendingIntent(R.id.widget_empty, open)

            val empty = content.rows.isEmpty()
            views.visible(R.id.widget_empty, empty)
            views.visible(R.id.widget_list, !empty)
            if (empty) {
                views.setTextViewText(R.id.widget_empty_title, context.getString(
                    if (content.initialized) R.string.today_widget_empty else R.string.today_widget_loading))
                val hint = when {
                    !content.initialized -> context.getString(R.string.today_widget_initial)
                    content.nextUp != null -> context.getString(R.string.today_widget_next, content.nextUp)
                    else -> null
                }
                views.visible(R.id.widget_empty_hint, hint != null)
                views.setTextViewText(R.id.widget_empty_hint, hint)
                return views
            }

            val template = PendingIntent.getActivity(context, 0,
                Intent(context, WidgetRowActivity::class.java),
                PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            views.setPendingIntentTemplate(R.id.widget_list, template)
            val list = RemoteViews.RemoteCollectionItems.Builder().setHasStableIds(true).setViewTypeCount(2)
            var coverCount = 0
            for (item in content.listItems(tall)) {
                when (item) {
                    is WidgetListItem.Heading -> {
                        val heading = RemoteViews(context.packageName, R.layout.today_widget_section)
                        heading.setTextViewText(R.id.widget_section, context.getString(item.section.label()))
                        list.addItem(stableId("section/${item.section}"), heading)
                    }
                    is WidgetListItem.Episode -> {
                        val row = item.row
                        val cover = if (tall && coverCount < TodayWidgetArtwork.MAX_COVERS_PER_WIDGET) {
                            TodayWidgetArtwork.cached(context, row.imageUrl)?.also { coverCount++ }
                        } else null
                        val episode = RemoteViews(context.packageName, R.layout.today_widget_row)
                        episode.setOnClickFillInIntent(R.id.widget_row,
                            Intent(WidgetRowActivity.OPEN_SERIES).putExtra(WidgetRowActivity.EXTRA_TITLE, row.title))
                        episode.visible(R.id.widget_art, tall)
                        if (tall) {
                            episode.setTextViewText(R.id.widget_monogram, row.displayTitle.take(1))
                            episode.visible(R.id.widget_poster, cover != null)
                            if (cover != null) episode.setImageViewBitmap(R.id.widget_poster, cover)
                        }
                        episode.setTextViewText(R.id.widget_series, row.displayTitle)
                        val status = context.getString(row.state.label())
                        val number = row.episode?.let { context.getString(R.string.today_widget_episode, it) }
                        val subtitle = when {
                            number == null -> status
                            tall && (row.state == TodayWidgetState.READY || row.state == TodayWidgetState.SETUP) -> number
                            else -> context.getString(R.string.today_widget_episode_status, number, status)
                        }
                        episode.setTextViewText(R.id.widget_subtitle, subtitle)
                        bindAction(context, episode, row, content.date, tall)
                        list.addItem(stableId("episode/${row.episodeKey ?: row.title}"), episode)
                    }
                }
            }
            views.setRemoteAdapter(R.id.widget_list, list.build())
            return views
        }

        private fun bindAction(context: Context, views: RemoteViews, row: TodayWidgetRow, date: LocalDate, tall: Boolean) {
            val action = row.action()
            views.visible(R.id.widget_action, action.canDownload || action.showProgress)
            views.setViewLayoutWidth(R.id.widget_action, if (tall) 48f else 104f, TypedValue.COMPLEX_UNIT_DIP)
            views.visible(R.id.widget_ready_button, action.canDownload)
            views.visible(R.id.widget_button_label, !tall)
            val label = context.getString(if (row.state == TodayWidgetState.FAILED) R.string.today_widget_retry else R.string.today_widget_download)
            views.setTextViewText(R.id.widget_button_label, label)
            views.visible(R.id.widget_bar, !tall && action.showProgress)
            views.visible(R.id.widget_ring, tall && action.showProgress && !action.indeterminate)
            views.visible(R.id.widget_spinner, tall && action.indeterminate)
            val percentText = action.percent?.let {
                NumberFormat.getPercentInstance(context.resources.configuration.locales[0]).format(it / 100.0)
            }
            val progressLabel = percentText ?: if (tall || row.state == TodayWidgetState.WAITING) "…" else context.getString(row.state.label())
            views.visible(R.id.widget_percent, action.showProgress && (!tall || !action.indeterminate))
            if (action.showProgress) {
                views.setProgressBar(if (tall) R.id.widget_ring else R.id.widget_bar, 100, action.percent ?: 0, !tall && action.indeterminate)
                views.setTextViewText(R.id.widget_percent, progressLabel)
            }
            val description = if (action.canDownload) label else listOfNotNull(context.getString(row.state.label()), percentText).joinToString(", ")
            val episodeLabel = row.episode?.let { context.getString(R.string.today_widget_episode, it) }
            val target = listOfNotNull(row.displayTitle, episodeLabel).joinToString(", ")
            val spoken = context.getString(R.string.today_widget_action_description, description, target)
            views.setContentDescription(R.id.widget_action, if (action.showProgress) spoken else null)
            if (action.canDownload) {
                views.setContentDescription(R.id.widget_ready_button, spoken)
                val fill = Intent(ACTION_DOWNLOAD).putExtra(EXTRA_KEY, row.episodeKey).putExtra(EXTRA_DATE, date.toString())
                views.setOnClickFillInIntent(R.id.widget_ready_button, fill)
            }
        }

        private fun stableId(key: String) = UUID.nameUUIDFromBytes(key.toByteArray(Charsets.UTF_8)).mostSignificantBits

        private fun RemoteViews.visible(id: Int, visible: Boolean) =
            setViewVisibility(id, if (visible) View.VISIBLE else View.GONE)

        private fun WidgetSection.label() = when (this) {
            WidgetSection.READY -> R.string.today_widget_ready
            WidgetSection.TRANSFERS -> R.string.today_widget_transfers
            WidgetSection.EXPECTED -> R.string.today_widget_expected
            WidgetSection.COMPLETE -> R.string.today_widget_complete
        }

        private fun TodayWidgetState.label() = when (this) {
            TodayWidgetState.EXPECTED -> R.string.today_widget_expected
            TodayWidgetState.READY, TodayWidgetState.SETUP -> R.string.today_widget_released
            TodayWidgetState.QUEUED -> R.string.today_widget_queued
            TodayWidgetState.DOWNLOADING -> R.string.today_widget_downloading
            TodayWidgetState.WAITING -> R.string.today_widget_waiting
            TodayWidgetState.PAUSED -> R.string.today_widget_paused
            TodayWidgetState.FAILED -> R.string.today_widget_failed
            TodayWidgetState.COMPLETE -> R.string.today_widget_complete
        }
    }
}
