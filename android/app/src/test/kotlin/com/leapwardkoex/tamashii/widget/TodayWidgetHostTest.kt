package com.leapwardkoex.tamashii.widget

import android.app.AppOpsManager
import android.app.Application
import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.Context
import android.os.Environment
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowEnvironment

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [31], application = Application::class)
class TodayWidgetHostTest {
    private val app: Application get() = RuntimeEnvironment.getApplication()
    private val prefs get() = app.getSharedPreferences("tamashii_widget", Context.MODE_PRIVATE)
    private val history get() = app.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    private val title = "Night Ferry"
    private val key = "Night Ferry-09"
    private val folder get() = app.filesDir.absolutePath

    @Before
    fun startWithEmptyStoresAndFolderAccess() {
        prefs.edit().clear().commit()
        history.edit().clear().commit()
        TodayWidgetHost.serviceStopped(app)
        ShadowEnvironment.addExternalDir("primary")
        val appOps = app.getSystemService(AppOpsManager::class.java)
        shadowOf(appOps).setMode("android:manage_external_storage", app.applicationInfo.uid, app.packageName, AppOpsManager.MODE_ALLOWED)
        assertTrue(Environment.isExternalStorageManager())
    }

    private fun episode(magnet: String = "magnet:test", released: Instant = Instant.now()) = mapOf(
        "key" to key, "title" to title, "episode" to "09", "releasedAt" to released.toEpochMilli(), "magnet" to magnet,
    )

    private fun catalog(magnet: String = "magnet:test", released: Instant = Instant.now()) = mapOf(
        "watching" to listOf(mapOf("title" to title, "weekday" to LocalDate.now().dayOfWeek.value, "folder" to folder)),
        "downloaded" to emptyList<String>(),
        "releases" to listOf(episode(magnet, released)),
    )

    private fun queue(at: Instant) {
        prefs.edit().putString("pending", JSONObject().put(key, at.toEpochMilli()).toString()).commit()
    }

    @Test
    fun delayedBootstrapAndCachedReleasesCannotOverwriteNewerAppOrFeedData() {
        val snapshot = catalog(magnet = "magnet:cached")
        TodayWidgetHost.publish(app, snapshot)
        TodayWidgetHost.publish(app, mapOf("releases" to listOf(episode("magnet:fresh"))))
        TodayWidgetHost.publish(app, mapOf(
            "bootstrap" to true,
            "watching" to emptyList<Any>(), "downloaded" to listOf(key), "releases" to emptyList<Any>(),
        ))
        assertEquals(TodayWidgetState.READY, TodayWidgetHost.content(app).rows.single().state)
        TodayWidgetHost.publish(app, snapshot)
        queue(Instant.now())
        assertEquals("magnet:fresh", TodayWidgetHost.pendingDownloads(app).single()["magnetUri"])
    }

    @Test
    fun correctingAReleaseChangesItsDisplayedIdentityWhilePreservingFreshFeedAndFolder() {
        val poster = "https://mal.test/correct.jpg"
        TodayWidgetHost.publish(app, catalog())
        val fresh = mapOf("releases" to listOf(episode("magnet:fresh")))
        TodayWidgetHost.publish(app, fresh)
        val corrected = episode() + mapOf("displayTitle" to "Correct Special", "catalogImageUrl" to poster)
        TodayWidgetHost.publish(app, catalog() + ("releases" to listOf(corrected)))
        TodayWidgetHost.publish(app, fresh)
        TodayWidgetHost.publish(app, catalog() + ("bootstrap" to true))
        val row = TodayWidgetHost.content(app).rows.single()
        assertEquals("Correct Special", row.displayTitle)
        assertEquals(poster, row.imageUrl)
        assertEquals(title, row.title)
        queue(Instant.now())
        assertEquals(mapOf("torrentKey" to key, "magnetUri" to "magnet:fresh", "downloadPath" to folder),
            TodayWidgetHost.pendingDownloads(app).single())
        TodayWidgetHost.publish(app, catalog())
        assertEquals(title, TodayWidgetHost.content(app).rows.single().displayTitle)
    }

    @Test
    fun freshColdRequestResolvesSavedMagnetAndDestinationOnceAcknowledged() {
        // These are the only inputs available to a newly created service engine with the app closed.
        prefs.edit().putString("catalog", JSONObject(catalog()).toString()).commit()
        queue(Instant.now())
        assertEquals(TodayWidgetState.QUEUED, TodayWidgetHost.content(app).rows.single().state)
        assertEquals(listOf(mapOf("torrentKey" to key, "magnetUri" to "magnet:test", "downloadPath" to folder)),
            TodayWidgetHost.pendingDownloads(app))
        TodayWidgetHost.transferState(app, mapOf("torrentKey" to key, "status" to "downloading", "progress" to 38))
        assertTrue(TodayWidgetHost.pendingDownloads(app).isEmpty())
        assertEquals(38, TodayWidgetHost.content(app).rows.single().progress)
    }

    @Test
    fun serviceHistorySurvivesLossOfTransientStateAndCanBeCleared() {
        TodayWidgetHost.publish(app, catalog())
        history.edit().putBoolean("flutter.downloaded_episode.$key", true).commit()
        TodayWidgetHost.serviceStopped(app)
        assertEquals(TodayWidgetState.COMPLETE, TodayWidgetHost.content(app).rows.single().state)
        queue(Instant.now())
        assertTrue(TodayWidgetHost.pendingDownloads(app).isEmpty())

        TodayWidgetHost.publish(app, mapOf("downloaded" to listOf(key)))
        history.edit().putBoolean("flutter.downloaded_episode.$key", false).commit()
        assertEquals(TodayWidgetState.READY, TodayWidgetHost.content(app).rows.single().state)
    }

    @Test
    fun staleTapOrPendingRequestCannotBePlayedAfterMidnightOrTimeout() {
        val midnight = LocalDate.now().atStartOfDay(ZoneId.systemDefault()).toInstant()
        val previous = midnight.minusSeconds(5)
        prefs.edit().putString("catalog", JSONObject(catalog(released = previous.minusSeconds(1))).toString()).commit()
        queue(previous)
        assertEquals(key, TodayWidgetHost.pendingDownloads(app, previous).single()["torrentKey"])
        assertTrue(TodayWidgetHost.pendingDownloads(app, midnight.plusSeconds(5)).isEmpty())
        assertFalse(JSONObject(prefs.getString("pending", "{}")!!).has(key))

        TodayWidgetHost.publish(app, catalog())
        TodayWidgetHost.onDownload(app, key, LocalDate.now().minusDays(1))
        assertTrue(TodayWidgetHost.pendingDownloads(app).isEmpty())
        val now = Instant.now()
        queue(now.minusSeconds(61))
        assertTrue(TodayWidgetHost.pendingDownloads(app, now).isEmpty())
        assertFalse(JSONObject(prefs.getString("pending", "{}")!!).has(key))
    }

    @Test
    fun unavailableStorageShowsSetupAndDoesNotQueueTheRelease() {
        ShadowEnvironment.reset()
        TodayWidgetHost.publish(app, catalog())
        assertEquals(TodayWidgetState.SETUP, TodayWidgetHost.content(app).rows.single().state)
        TodayWidgetHost.onDownload(app, key, LocalDate.now())
        assertTrue(TodayWidgetHost.pendingDownloads(app).isEmpty())
    }

    @Test
    fun firstBootstrapRunsOfflineAndSubsequentFeedRefreshNeedsNetwork() {
        val jobs = app.getSystemService(JobScheduler::class.java)
        TodayWidgetHost.onEnabled(app)
        val first = jobs.allPendingJobs.single()
        assertNull(first.requiredNetwork)
        assertEquals(0, first.maxExecutionDelayMillis)
        // A zero deadline and an absent deadline share the same public getter.
        assertEquals(true, JobInfo::class.java.getMethod("hasLateConstraint").invoke(first))
        TodayWidgetHost.onEnabled(app)
        assertEquals(1, jobs.allPendingJobs.size)
        TodayWidgetHost.onDisabled(app)
        assertTrue(jobs.allPendingJobs.isEmpty())

        TodayWidgetHost.publish(app, catalog())
        TodayWidgetHost.onEnabled(app)
        assertTrue(jobs.allPendingJobs.single().requiredNetwork != null)
    }
}
