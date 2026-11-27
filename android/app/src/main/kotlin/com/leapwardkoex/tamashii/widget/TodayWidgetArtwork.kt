package com.leapwardkoex.tamashii.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.util.AtomicFile
import android.util.LruCache
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URI
import java.nio.ByteBuffer
import java.security.MessageDigest
import kotlin.math.roundToInt

/** Small local covers for RemoteViews. Network and full image decoding run only in the refresh job. */
object TodayWidgetArtwork {
    private const val MAX_SOURCE_BYTES = 2 * 1024 * 1024
    internal const val MAX_COVERS_PER_WIDGET = 8
    private const val MAX_EDGE = 80
    private val memory = LruCache<String, Bitmap>(32)

    internal fun resolvedUrl(path: String?): String? {
        if (path.isNullOrBlank()) return null
        val uri = runCatching { URI("https://subsplease.org/").resolve(path.trim()) }.getOrNull()
        return uri?.takeIf { it.scheme.equals("https", ignoreCase = true) && !it.host.isNullOrBlank() }?.toString()
    }

    private fun directory(context: Context) = File(context.cacheDir, "today-widget-covers")

    private fun cacheFile(context: Context, url: String): File {
        val digest = MessageDigest.getInstance("SHA-256").digest(url.toByteArray(Charsets.UTF_8))
        return File(directory(context), digest.joinToString("") { "%02x".format(it) } + ".jpg")
    }

    internal fun cached(context: Context, path: String?): Bitmap? {
        val url = resolvedUrl(path) ?: return null
        memory.get(url)?.let { return it }
        val file = cacheFile(context, url)
        if (!file.isFile) return null
        return BitmapFactory.decodeFile(file.path)?.also { memory.put(url, it) }
    }

    fun prefetch(context: Context, rows: List<TodayWidgetRow>) {
        val urls = rows.mapNotNull { resolvedUrl(it.imageUrl) }.distinct().take(MAX_COVERS_PER_WIDGET)
        if (urls.isEmpty()) return
        directory(context).mkdirs()
        for (url in urls) {
            if (cached(context, url) != null) continue
            try {
                val bitmap = fetchCover(url) ?: continue
                val file = AtomicFile(cacheFile(context, url))
                val stream = file.startWrite()
                try {
                    if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 88, stream)) throw IOException("JPEG encoding failed")
                    file.finishWrite(stream)
                } catch (error: IOException) {
                    file.failWrite(stream)
                    throw error
                }
                memory.put(url, bitmap)
            } catch (_: IOException) {
                // A missing or invalid cover leaves the title's monogram visible.
            }
        }
        directory(context).listFiles()?.filter { it.extension == "jpg" }
            ?.sortedByDescending { it.lastModified() }?.drop(32)?.forEach { it.delete() }
    }

    private fun fetchCover(url: String): Bitmap? {
        val connection = URI(url).toURL().openConnection() as HttpURLConnection
        try {
            connection.connectTimeout = 3_000
            connection.readTimeout = 3_000
            if (connection.responseCode !in 200..299 || connection.contentLengthLong > MAX_SOURCE_BYTES) return null
            val bytes = ByteArrayOutputStream()
            connection.inputStream.use { input ->
                val buffer = ByteArray(8192)
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    if (bytes.size() + count > MAX_SOURCE_BYTES) return null
                    bytes.write(buffer, 0, count)
                }
            }
            if (bytes.size() == 0) return null
            return ImageDecoder.decodeBitmap(ImageDecoder.createSource(ByteBuffer.wrap(bytes.toByteArray()))) { decoder, info, _ ->
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                val scale = minOf(1.0, MAX_EDGE.toDouble() / maxOf(info.size.width, info.size.height))
                decoder.setTargetSize(
                    (info.size.width * scale).roundToInt().coerceAtLeast(1),
                    (info.size.height * scale).roundToInt().coerceAtLeast(1),
                )
            }
        } finally {
            connection.disconnect()
        }
    }
}
