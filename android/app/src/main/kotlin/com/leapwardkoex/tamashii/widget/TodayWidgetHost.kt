package com.leapwardkoex.tamashii.widget

import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import com.leapwardkoex.tamashii.MainActivity
import com.pravera.flutter_foreground_task.service.ForegroundServiceManager
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

private fun JSONObject.objects(key: String): List<JSONObject> {
    val array = optJSONArray(key) ?: return emptyList()
    return (0 until array.length()).mapNotNull { array.optJSONObject(it) }
}

// The foreground-task plugin consumes ordinary codec lists/maps, including its nested options.
private fun unpackJson(value: Any?): Any? = when (value) {
    is JSONObject -> value.keys().asSequence().associateWith { unpackJson(value.get(it)) }
    is JSONArray -> (0 until value.length()).map { unpackJson(value.get(it)) }
    JSONObject.NULL -> null
    else -> value
}

object TodayWidgetHost {
    private const val STORE = "tamashii_widget"
    private const val CATALOG = "catalog"
    private const val PENDING = "pending"
    private const val REFRESH_JOB = 0x5457
    private const val START_TIMEOUT = 60_000L
    const val SETUP = "com.leapwardkoex.tamashii.WIDGET_SETUP"
    private val service = ForegroundServiceManager()
    // Transient status belongs to the live torrent process. After process death a transfer
    // can be started again, while completed keys remain in the shared download history.
    private val transfers = mutableMapOf<String, WidgetTransfer>()
    private var starting = false
    private fun prefs(context: Context) = context.getSharedPreferences(STORE, Context.MODE_PRIVATE)
    private fun saved(context: Context) = JSONObject(prefs(context).getString(CATALOG, "{}")!!)
    fun hasCatalog(context: Context) = saved(context).has("watching")

    fun publish(context: Context, update: Map<*, *>) {
        val previous = saved(context)
        val incoming = JSONObject(update)
        if (!(incoming.optBoolean("bootstrap") && previous.has("watching"))) {
            for (field in listOf("watching", "downloaded")) {
                if (incoming.has(field)) previous.put(field, incoming.get(field))
            }
        }
        if (incoming.has("serviceOptions")) previous.put("serviceOptions", incoming.get("serviceOptions"))
        val watched = previous.objects("watching").filterNot { it.optBoolean("manual") }
            .map { it.getString("title") }.toSet()
        val cutoff = Instant.now().minus(Duration.ofDays(2)).toEpochMilli()
        val episodes = previous.objects("releases").associateByTo(mutableMapOf()) { it.getString("key") }
        val freshFeed = !incoming.has("watching")
        for (episode in incoming.objects("releases")) {
            val key = episode.getString("key")
            // Flutter also publishes cached rows on a folder/bookmark change. Preserve any
            // updated timestamp or magnet that a background feed request already discovered.
            if (freshFeed || episodes[key]?.optBoolean("fromFeed") != true) {
                episodes[key] = episode.put("fromFeed", freshFeed)
            }
        }
        episodes.entries.removeAll { (_, episode) ->
            episode.optLong("releasedAt") < cutoff || episode.optString("title") !in watched
        }
        previous.put("releases", JSONArray(episodes.values))
        prefs(context).edit().putString(CATALOG, previous.toString()).apply()
        TodayWidgetProvider.redraw(context)
    }

    private fun catalog(json: JSONObject): WidgetCatalog {
        val watching = json.objects("watching").map {
            WatchedTitle(it.getString("title"), it.getInt("weekday"), it.optBoolean("manual"),
                it.optString("folder"), it.optString("imageUrl").takeIf(String::isNotBlank))
        }
        val episodes = json.objects("releases").map {
            ReleasedEpisode(it.getString("key"), it.getString("title"), it.getString("episode"),
                it.getLong("releasedAt"), it.getString("magnet"), it.optString("imageUrl").takeIf(String::isNotBlank))
        }
        val downloaded = json.optJSONArray("downloaded") ?: JSONArray()
        return WidgetCatalog(watching.associateBy { it.title }, episodes.associateBy { it.key },
            (0 until downloaded.length()).map { downloaded.getString(it) }.toSet(), json.has("watching"))
    }

    /** Only a fresh tap can initiate a transfer. An old queued click must expire after a crash. */
    private fun pending(context: Context, now: Instant = Instant.now()): JSONObject {
        val requests = JSONObject(prefs(context).getString(PENDING, "{}")!!)
        val cutoff = now.toEpochMilli() - START_TIMEOUT
        val expired = requests.keys().asSequence().filter { requests.getLong(it) < cutoff }.toList()
        if (expired.isNotEmpty()) {
            expired.forEach(requests::remove)
            savePending(context, requests)
        }
        return requests
    }

    private fun savePending(context: Context, requests: JSONObject) {
        prefs(context).edit().putString(PENDING, requests.toString()).apply()
    }

    private fun project(context: Context, source: WidgetCatalog, queued: Set<String>,
                        now: Instant = Instant.now(), zone: ZoneId = ZoneId.systemDefault()): TodayWidgetContent {
        // Android 12's no-argument permission query reads the first shared volume.
        // It can be absent while storage is unavailable (including during boot).
        val storageAllowed = try {
            Environment.isExternalStorageManager()
        } catch (_: IndexOutOfBoundsException) {
            false
        }
        val allowed = storageAllowed &&
            (Build.VERSION.SDK_INT < 33 || NotificationManagerCompat.from(context).areNotificationsEnabled())
        val legacy = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return source.project(now, zone, transfers, queued,
            canStart = { allowed && it.folder.isNotBlank() && writableDestination(File(it.folder)) },
            completionOverride = { key ->
                val marker = "flutter.downloaded_episode.$key"
                if (legacy.contains(marker)) legacy.getBoolean(marker, false) else null
            })
    }

    private fun writableDestination(directory: File): Boolean {
        var parent = directory.absoluteFile
        while (!parent.exists()) parent = parent.parentFile ?: return false
        return parent.isDirectory && parent.canWrite()
    }

    fun content(context: Context) =
        project(context, catalog(saved(context)), pending(context).keys().asSequence().toSet())

    fun onDownload(context: Context, episodeKey: String, localDate: LocalDate) {
        val current = content(context)
        val row = current.rows.find { it.episodeKey == episodeKey }
        if (current.date != localDate || row?.state !in setOf(TodayWidgetState.READY, TodayWidgetState.FAILED)) {
            TodayWidgetProvider.redraw(context)
            return
        }
        val options = saved(context).optJSONObject("serviceOptions")
        if (options == null || !options.has("callbackHandle")) {
            onEnabled(context)
            return
        }
        transfers.remove(episodeKey)
        val requests = pending(context).put(episodeKey, System.currentTimeMillis())
        savePending(context, requests)
        try {
            if (service.isRunningService()) {
                service.sendData(mapOf("type" to "widget_downloads_pending"))
            } else if (!starting) {
                starting = true
                service.start(context, unpackJson(options))
            }
        } catch (error: Exception) {
            starting = false
            Log.e("TamashiiWidget", "Unable to start the torrent service", error)
            requests.remove(episodeKey)
            savePending(context, requests)
            transfers[episodeKey] = WidgetTransfer(TodayWidgetState.FAILED)
        }
        TodayWidgetProvider.redraw(context)
        Handler(Looper.getMainLooper()).postDelayed({
            if (!service.isRunningService()) starting = false
            TodayWidgetProvider.redraw(context)
        }, START_TIMEOUT + 100)
    }

    fun pendingDownloads(context: Context, now: Instant = Instant.now()): List<Map<String, String>> {
        starting = false
        val requests = pending(context, now)
        if (requests.length() == 0) return emptyList()
        val source = catalog(saved(context))
        val zone = ZoneId.systemDefault()
        val current = project(context, source, emptySet(), now, zone)
        val eligible = current.rows
            .filter { it.state == TodayWidgetState.READY || it.state == TodayWidgetState.FAILED }
            .mapNotNull { it.episodeKey }.toSet()
        val keys = requests.keys().asSequence().toList()
        val result = mutableListOf<Map<String, String>>()
        for (key in keys) {
            val release = source.releases[key]
            val requestedDate = Instant.ofEpochMilli(requests.getLong(key)).atZone(zone).toLocalDate()
            if (key !in eligible || release == null || requestedDate != current.date) {
                requests.remove(key)
                continue
            }
            result += mapOf("torrentKey" to key, "magnetUri" to release.magnet,
                "downloadPath" to source.watching.getValue(release.title).folder)
        }
        if (requests.length() != keys.size) savePending(context, requests)
        return result
    }

    fun transferState(context: Context, update: Map<*, *>) {
        val key = update["torrentKey"] as? String ?: return
        val state = when (update["status"]) {
            "queued" -> TodayWidgetState.QUEUED
            "downloading" -> TodayWidgetState.DOWNLOADING
            "waiting" -> TodayWidgetState.WAITING
            "paused" -> TodayWidgetState.PAUSED
            "failed" -> TodayWidgetState.FAILED
            "completed" -> TodayWidgetState.COMPLETE
            "removed" -> null
            else -> return
        }
        val old = transfers[key]
        if (state == null) transfers.remove(key)
        else transfers[key] = WidgetTransfer(state, (update["progress"] as? Number)?.toInt()?.coerceIn(0,100))
        val requests = pending(context)
        val acknowledged = requests.remove(key) != null
        if (acknowledged) savePending(context, requests)
        if (acknowledged || old != transfers[key]) TodayWidgetProvider.redraw(context)
    }

    fun serviceStopped(context: Context) {
        starting = false
        transfers.clear()
        TodayWidgetProvider.redraw(context)
    }

    fun setupIntent(context: Context, episodeKey: String, localDate: LocalDate): Intent =
        Intent(context, MainActivity::class.java).setAction(SETUP)
            .setIdentifier("${localDate}/${episodeKey}").putExtra("episode", episodeKey)
            .putExtra("date", localDate.toString()).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)

    fun setupTitle(context: Context, intent: Intent?): String? {
        if (intent?.action != SETUP) return null
        val current = content(context)
        if (intent.getStringExtra("date") != current.date.toString()) return null
        return current.rows.find { it.episodeKey == intent.getStringExtra("episode") &&
            it.state == TodayWidgetState.SETUP }?.title
    }

    fun onEnabled(context: Context) {
        val scheduler = context.getSystemService(JobScheduler::class.java)
        if (scheduler.getPendingJob(REFRESH_JOB) == null) {
            val job = JobInfo.Builder(REFRESH_JOB, ComponentName(context, WidgetRefreshJob::class.java))
            // First placement can bootstrap the saved schedule even while offline.
            if (hasCatalog(context)) {
                job.setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
            } else {
                job.setOverrideDeadline(0)
            }
            scheduler.schedule(job.build())
        }
    }

    fun onDisabled(context: Context) = context.getSystemService(JobScheduler::class.java).cancel(REFRESH_JOB)
}
