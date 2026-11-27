package com.leapwardkoex.tamashii.widget

import java.time.LocalDate

data class TodayWidgetContent(
    val date: LocalDate,
    val rows: List<TodayWidgetRow>,
    val nextUp: String? = null,
    val initialized: Boolean = true,
)

data class TodayWidgetRow(
    val title: String,
    val state: TodayWidgetState,
    val episodeKey: String? = null,
    val episode: String? = null,
    val progress: Int? = null,
    val imageUrl: String? = null,
    val displayTitle: String = title,
)

enum class TodayWidgetState {
    EXPECTED, READY, SETUP, QUEUED, DOWNLOADING, WAITING, PAUSED, FAILED, COMPLETE;

    val section: WidgetSection get() = when (this) {
        READY, FAILED, SETUP -> WidgetSection.READY
        QUEUED, DOWNLOADING, WAITING, PAUSED -> WidgetSection.TRANSFERS
        EXPECTED -> WidgetSection.EXPECTED
        COMPLETE -> WidgetSection.COMPLETE
    }
}

enum class WidgetSection { READY, TRANSFERS, EXPECTED, COMPLETE }

internal sealed interface WidgetListItem {
    data class Heading(val section: WidgetSection) : WidgetListItem
    data class Episode(val row: TodayWidgetRow) : WidgetListItem
}

internal fun TodayWidgetContent.listItems(tall: Boolean): List<WidgetListItem> = buildList {
    val groups = rows.groupBy { it.state.section }
    for (section in WidgetSection.entries) {
        val episodes = groups[section] ?: continue
        if (tall) add(WidgetListItem.Heading(section))
        episodes.forEach { add(WidgetListItem.Episode(it)) }
    }
}

internal data class WidgetAction(
    val canDownload: Boolean,
    val showProgress: Boolean,
    val percent: Int?,
    val indeterminate: Boolean,
)

internal fun TodayWidgetRow.action(): WidgetAction {
    val canDownload = !episodeKey.isNullOrEmpty() &&
        (state == TodayWidgetState.READY || state == TodayWidgetState.SETUP || state == TodayWidgetState.FAILED)
    val showProgress = state.section == WidgetSection.TRANSFERS
    val percent = progress?.coerceIn(0, 100)
    val indeterminate = percent == null && (state == TodayWidgetState.QUEUED || state == TodayWidgetState.DOWNLOADING)
    return WidgetAction(canDownload, showProgress, percent, indeterminate)
}
