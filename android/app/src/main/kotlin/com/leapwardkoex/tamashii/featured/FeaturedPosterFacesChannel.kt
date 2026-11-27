package com.leapwardkoex.tamashii.featured

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

internal class FeaturedPosterFacesChannel(context: Context, messenger: BinaryMessenger) : AutoCloseable {
    private val worker = PosterFaceWorker(
        createDetector = { DeepGhsPosterFaceDetector(context.assets) },
        onFailure = { Log.w("FeaturedPosterFaces", "Poster face detection unavailable", it) },
    )
    private val channel = MethodChannel(messenger, "tamashii/featured_poster_faces")

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "detectFaces") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = (call.arguments as? Map<*, *>)?.get("path") as? String
            if (path.isNullOrBlank()) {
                result.success(null)
                return@setMethodCallHandler
            }
            worker.detect(File(path)) { analysis ->
                result.success(analysis?.toChannelValue())
            }
        }
    }

    override fun close() {
        channel.setMethodCallHandler(null)
        worker.close()
    }
}

internal interface PosterFaceDetector : AutoCloseable {
    fun detect(file: File): PosterFaceAnalysis
}

internal data class PosterFaceAnalysis(val width: Int, val height: Int, val faces: List<PosterFaceBox>) {
    fun toChannelValue(): Map<String, Any> = mapOf(
        "width" to width,
        "height" to height,
        "faces" to faces.map { listOf(it.left, it.top, it.right, it.bottom, it.confidence) },
    )
}

internal data class PosterFaceBox(
    val left: Double,
    val top: Double,
    val right: Double,
    val bottom: Double,
    val confidence: Double,
)

internal class PosterFaceWorker(
    private val createDetector: () -> PosterFaceDetector,
    private val onFailure: (Throwable) -> Unit,
) : AutoCloseable {
    private val executor = Executors.newSingleThreadExecutor { task ->
        Thread(task, "featured-poster-faces")
    }
    // All accesses, including close, are serialized on the same worker.
    private var detector: PosterFaceDetector? = null
    private var unavailable = false
    @Volatile
    private var closed = false

    @Synchronized
    fun detect(file: File, complete: (PosterFaceAnalysis?) -> Unit) {
        if (closed) {
            complete(null)
            return
        }
        executor.execute {
            val analysis = if (closed || unavailable) null else orNull {
                val activeDetector = detector ?: createDetector().also { detector = it }
                activeDetector.detect(file)
            }
            complete(if (closed) null else analysis)
        }
    }

    @Synchronized
    override fun close() {
        if (closed) return
        closed = true
        executor.execute {
            orNull { detector?.close() }
            detector = null
        }
        executor.shutdown()
    }

    private inline fun <T> orNull(operation: () -> T): T? {
        try {
            return operation()
        } catch (failure: Exception) {
            onFailure(failure)
        } catch (failure: LinkageError) {
            // A missing or incompatible native library cannot recover in this process.
            unavailable = true
            onFailure(failure)
        }
        return null
    }
}
