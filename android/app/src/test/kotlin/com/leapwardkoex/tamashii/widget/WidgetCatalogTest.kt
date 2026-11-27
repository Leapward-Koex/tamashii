package com.leapwardkoex.tamashii.widget

import java.time.Instant
import java.time.ZoneId
import org.junit.Assert.*
import org.junit.Test

class WidgetCatalogTest {
    private val now = Instant.parse("2026-11-26T11:05:00Z") // Friday, five minutes after midnight in Auckland
    private val zone = ZoneId.of("Pacific/Auckland")
    private fun watched(name: String, day: Int, manual: Boolean = false) =
        WatchedTitle(name, day, manual, "/downloads", null)

    private fun episode(name: String, number: String = "03", age: Long = 60) =
        ReleasedEpisode("$name-$number", name, number, now.minusSeconds(age).toEpochMilli(), "magnet:test", null)

    private fun project(
        titles: List<WatchedTitle>, episodes: List<ReleasedEpisode>,
        completed: Set<String> = emptySet(), queued: Set<String> = emptySet(),
        transfers: Map<String, WidgetTransfer> = emptyMap(), allowed: Boolean = true,
        marker: Boolean? = null,
    ) = WidgetCatalog(titles.associateBy { it.title }, episodes.associateBy { it.key }, completed, true)
        .project(now, zone, transfers, queued, { allowed }, { marker })

    @Test fun matchesLocalReleaseAndScheduleIndependently() {
        val titles = listOf(watched("Late", 4), watched("Today", 5), watched("Manual", 5, true))
        val content = project(titles, listOf(episode("Late"), episode("Today"), episode("Manual"),
            episode("Unwatched"), episode("Late", "02", 360), episode("Late", "04", -900)))
        assertEquals(listOf("Late-03", "Today-03", null), content.rows.map { it.episodeKey })
        assertEquals(listOf(TodayWidgetState.READY, TodayWidgetState.READY, TodayWidgetState.EXPECTED),
            content.rows.map { it.state })
    }

    @Test fun queueHistoryAndProgressPreserveOneRowPerEpisode() {
        val title = watched("Today", 5)
        val episodes = listOf(episode("Today"), episode("Today", "04"), episode("Today", "05"))
        val content = project(listOf(title), episodes, setOf("Today-03"), setOf("Today-04"),
            mapOf("Today-05" to WidgetTransfer(TodayWidgetState.DOWNLOADING, 61)))
        assertEquals(listOf(TodayWidgetState.COMPLETE, TodayWidgetState.QUEUED, TodayWidgetState.DOWNLOADING),
            content.rows.map { it.state })
        assertEquals(61, content.rows.last().progress)
    }

    @Test fun respectsSetupChangesAndCrossEngineCompletionMarkers() {
        val titles = listOf(watched("Today", 5))
        val episodes = listOf(episode("Today"))
        assertEquals(TodayWidgetState.SETUP, project(titles, episodes, allowed = false).rows.single().state)
        assertEquals(TodayWidgetState.COMPLETE, project(titles, episodes, marker = true).rows.single().state)
        assertEquals(TodayWidgetState.READY, project(titles, episodes, completed = setOf("Today-03"),
            marker = false).rows.single().state)
    }

    @Test fun quietDayFindsNextWatchedShow() {
        val content = project(listOf(watched("Monday show", 1), watched("Saturday show", 6)), emptyList())
        assertTrue(content.rows.isEmpty())
        assertTrue(content.nextUp!!.startsWith("Saturday show on "))
        assertNull(project(emptyList(), emptyList()).nextUp)
    }
}
