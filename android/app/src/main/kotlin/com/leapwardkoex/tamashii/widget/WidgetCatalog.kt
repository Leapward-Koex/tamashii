package com.leapwardkoex.tamashii.widget

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.TextStyle
import java.util.Locale

internal data class WatchedTitle(
    val title: String, val weekday: Int, val manual: Boolean,
    val folder: String, val imageUrl: String?,
)

internal data class ReleasedEpisode(
    val key: String, val title: String, val episode: String, val releasedAt: Long,
    val magnet: String, val imageUrl: String?,
)

internal data class WidgetTransfer(val state: TodayWidgetState, val percent: Int? = null)

/** Join on the same feed title and episode key that the app uses for download history. */
internal class WidgetCatalog(
    val watching: Map<String, WatchedTitle>,
    val releases: Map<String, ReleasedEpisode>,
    private val downloaded: Set<String>,
    val initialized: Boolean,
) {
    fun project(
        now: Instant, zone: ZoneId, transfers: Map<String, WidgetTransfer>,
        pending: Set<String>, canStart: (WatchedTitle) -> Boolean,
        completionOverride: (String) -> Boolean?,
    ): TodayWidgetContent {
        val date = now.atZone(zone).toLocalDate()
        val releasedTitles = mutableSetOf<String>()
        val rows = mutableListOf<TodayWidgetRow>()
        for (release in releases.values.sortedByDescending { it.releasedAt }) {
            val watched = watching[release.title] ?: continue
            val published = Instant.ofEpochMilli(release.releasedAt)
            if (watched.manual || published > now || published.atZone(zone).toLocalDate() != date) continue
            if (release.magnet.isBlank()) continue
            releasedTitles.add(watched.title)
            val transfer = transfers[release.key]
            val completed = completionOverride(release.key) ?: (release.key in downloaded)
            val state = when {
                transfer != null && transfer.state != TodayWidgetState.FAILED -> transfer.state
                completed -> TodayWidgetState.COMPLETE
                release.key in pending -> TodayWidgetState.QUEUED
                !canStart(watched) -> TodayWidgetState.SETUP
                transfer != null -> transfer.state
                else -> TodayWidgetState.READY
            }
            rows.add(TodayWidgetRow(watched.title, state, release.key, release.episode,
                transfer?.percent, release.imageUrl ?: watched.imageUrl))
        }
        watching.values.filter { it.weekday == date.dayOfWeek.value && it.title !in releasedTitles }
            .sortedBy { it.title }.forEach {
                rows.add(TodayWidgetRow(it.title, TodayWidgetState.EXPECTED, imageUrl = it.imageUrl))
            }
        return TodayWidgetContent(date, rows, nextUp(date), initialized)
    }

    private fun nextUp(today: LocalDate): String? {
        for (offset in 1L..7L) {
            val day = today.plusDays(offset).dayOfWeek
            val first = watching.values.filter { it.weekday == day.value }.minByOrNull { it.title }
            if (first != null) return "${first.title} on ${day.getDisplayName(TextStyle.FULL, Locale.getDefault())}"
        }
        return null
    }
}
