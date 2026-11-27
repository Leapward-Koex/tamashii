package com.leapwardkoex.tamashii.featured

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.res.AssetManager
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.system.Os
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.roundToInt

private const val MODEL_ASSET = "face_detect_v1.4_n.onnx"
private const val MODEL_SIZE = 640
private const val MAX_DECODE_SIZE = 1_280
private const val PIXEL_COUNT = MODEL_SIZE * MODEL_SIZE
private const val CONFIDENCE_THRESHOLD = 0.25f
private const val OVERLAP_THRESHOLD = 0.70

internal class DeepGhsPosterFaceDetector(assets: AssetManager) : PosterFaceDetector {
    private val pixels = IntArray(PIXEL_COUNT)
    private val input = ByteBuffer.allocateDirect(3 * PIXEL_COUNT * Float.SIZE_BYTES)
        .order(ByteOrder.nativeOrder())
        .asFloatBuffer()
    private val environment = run {
        // Disable the uploader before the native runtime initializes.
        Os.setenv("ORT_DISABLE_TELEMETRY", "1", true)
        OrtEnvironment.getEnvironment().also { it.setTelemetry(false) }
    }
    private val session = OrtSession.SessionOptions().use { options ->
        options.setIntraOpNumThreads(2)
        options.setExecutionMode(OrtSession.SessionOptions.ExecutionMode.SEQUENTIAL)
        val model = assets.open(MODEL_ASSET).use { it.readBytes() }
        environment.createSession(model, options)
    }

    override fun detect(file: File): PosterFaceAnalysis {
        var width = 0
        var height = 0
        val poster = ImageDecoder.decodeBitmap(ImageDecoder.createSource(file)) { decoder, image, _ ->
            decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            width = image.size.width
            height = image.size.height
            val longestEdge = maxOf(width, height)
            if (longestEdge > MAX_DECODE_SIZE) {
                val scale = MAX_DECODE_SIZE.toDouble() / longestEdge
                decoder.setTargetSize(
                    (width * scale).roundToInt().coerceAtLeast(1),
                    (height * scale).roundToInt().coerceAtLeast(1),
                )
            }
        }
        try {
            encode(poster)
        } finally {
            poster.recycle()
        }
        val shape = longArrayOf(1, 3, MODEL_SIZE.toLong(), MODEL_SIZE.toLong())
        OnnxTensor.createTensor(environment, input, shape).use { image ->
            session.run(mapOf("images" to image)).use { result ->
                val output = result[0].value as Array<*>
                val channels = (output.single() as Array<*>).map { it as FloatArray }
                return PosterFaceAnalysis(width, height, decodeDeepGhsFaces(channels))
            }
        }
    }

    private fun encode(poster: Bitmap) {
        // DeepGHS resizes the input to a 640 × 640 RGB tensor without padding.
        val resized = Bitmap.createScaledBitmap(poster, MODEL_SIZE, MODEL_SIZE, true)
        try {
            resized.getPixels(pixels, 0, MODEL_SIZE, 0, 0, MODEL_SIZE, MODEL_SIZE)
        } finally {
            if (resized !== poster) resized.recycle()
        }
        for (index in pixels.indices) {
            val argb = pixels[index]
            input.put(index, (argb ushr 16 and 0xff) / 255f)
            input.put(index + PIXEL_COUNT, (argb ushr 8 and 0xff) / 255f)
            input.put(index + 2 * PIXEL_COUNT, (argb and 0xff) / 255f)
        }
    }

    override fun close() {
        session.close()
    }
}

/** Model rows are center x, center y, width, height, and the face score. */
internal fun decodeDeepGhsFaces(channels: List<FloatArray>): List<PosterFaceBox> {
    require(channels.size == 5) { "Expected five DeepGHS output channels" }
    val candidates = mutableListOf<PosterFaceBox>()
    for (index in channels[4].indices) {
        val confidence = channels[4][index]
        if (!(confidence > CONFIDENCE_THRESHOLD)) continue
        val centerX = channels[0][index].toDouble()
        val centerY = channels[1][index].toDouble()
        val halfWidth = channels[2][index] / 2.0
        val halfHeight = channels[3][index] / 2.0
        if (halfWidth <= 0 || halfHeight <= 0) continue
        candidates += PosterFaceBox(
            centerX - halfWidth,
            centerY - halfHeight,
            centerX + halfWidth,
            centerY + halfHeight,
            confidence.toDouble(),
        )
    }

    val kept = mutableListOf<PosterFaceBox>()
    for (candidate in candidates.sortedByDescending { it.confidence }) {
        if (kept.none { overlap(it, candidate) > OVERLAP_THRESHOLD }) kept += candidate
    }
    return kept.mapNotNull { box ->
        val left = normalize(box.left)
        val top = normalize(box.top)
        val right = normalize(box.right)
        val bottom = normalize(box.bottom)
        if (left < right && top < bottom) {
            PosterFaceBox(left, top, right, bottom, box.confidence)
        } else {
            null
        }
    }
}

private fun overlap(first: PosterFaceBox, second: PosterFaceBox): Double {
    val width = (minOf(first.right, second.right) - maxOf(first.left, second.left) + 1).coerceAtLeast(0.0)
    val height = (minOf(first.bottom, second.bottom) - maxOf(first.top, second.top) + 1).coerceAtLeast(0.0)
    val intersection = width * height
    val firstArea = (first.right - first.left + 1) * (first.bottom - first.top + 1)
    val secondArea = (second.right - second.left + 1) * (second.bottom - second.top + 1)
    return intersection / (firstArea + secondArea - intersection)
}

private fun normalize(value: Double): Double = (value / MODEL_SIZE).coerceIn(0.0, 1.0)
