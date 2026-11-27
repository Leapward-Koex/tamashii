package com.leapwardkoex.tamashii.featured

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.io.IOException
import java.util.concurrent.CompletableFuture
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit.SECONDS
import java.util.concurrent.atomic.AtomicInteger

class FeaturedPosterFacesTest {
    @Test
    fun detectsNormalizedFacesWithoutLowConfidenceOrDuplicateBoxes() {
        val faces = decodeDeepGhsFaces(listOf(
            floatArrayOf(101f, 100f, 450f, 550f),
            floatArrayOf(102f, 100f, 350f, 400f),
            floatArrayOf(96f, 100f, 60f, 32f),
            floatArrayOf(96f, 100f, 30f, 32f),
            floatArrayOf(0.70f, 0.90f, 0.80f, 0.25f),
        ))

        assertEquals(2, faces.size)
        assertEquals(50.0 / 640, faces.first().left, DELTA)
        assertEquals(150.0 / 640, faces.first().bottom, DELTA)
        assertEquals(0.90, faces.first().confidence, DELTA)
        assertEquals(420.0 / 640, faces.last().left, DELTA)
        assertEquals(335.0 / 640, faces.last().top, DELTA)
    }

    @Test
    fun clipsBoxesToSourceBoundaryAndDropsBoxesEntirelyOutside() {
        val face = decodeDeepGhsFaces(listOf(
            floatArrayOf(5f, 700f),
            floatArrayOf(635f, 100f),
            floatArrayOf(40f, 10f),
            floatArrayOf(30f, 10f),
            floatArrayOf(0.9f, 0.8f),
        )).single()

        assertEquals(0.0, face.left, DELTA)
        assertEquals(620.0 / 640, face.top, DELTA)
        assertEquals(25.0 / 640, face.right, DELTA)
        assertEquals(1.0, face.bottom, DELTA)
    }

    @Test
    fun serializesSourceDimensionsAndFiveNativeDoubleCoordinates() {
        val analysis = PosterFaceAnalysis(
            width = 427,
            height = 600,
            faces = listOf(PosterFaceBox(0.1, 0.2, 0.3, 0.4, 0.95)),
        )

        assertEquals(
            mapOf("width" to 427, "height" to 600, "faces" to listOf(listOf(0.1, 0.2, 0.3, 0.4, 0.95))),
            analysis.toChannelValue(),
        )
    }

    @Test
    fun initializesLazilyAndReusesDetectorAfterAFileFails() {
        val opens = AtomicInteger()
        val closed = CountDownLatch(1)
        val captured = CompletableFuture<Throwable>()
        val worker = PosterFaceWorker(createDetector = {
            opens.incrementAndGet()
            object : PosterFaceDetector {
                override fun detect(file: File): PosterFaceAnalysis {
                    if (file.name == "bad") throw IOException("invalid artwork")
                    return PosterFaceAnalysis(100, 200, emptyList())
                }

                override fun close() {
                    closed.countDown()
                }
            }
        }, onFailure = { captured.complete(it) })

        try {
            assertEquals(0, opens.get())
            assertNull(worker.analyze("bad").get(3, SECONDS))
            assertEquals("invalid artwork", captured.get(3, SECONDS).message)
            assertEquals(PosterFaceAnalysis(100, 200, emptyList()), worker.analyze("good").get(3, SECONDS))
            assertEquals(1, opens.get())
        } finally {
            worker.close()
        }
        assertTrue(closed.await(3, SECONDS))
    }

    @Test
    fun retriesAfterTransientDetectorInitializationFailure() {
        val attempts = AtomicInteger()
        val worker = PosterFaceWorker(createDetector = {
            if (attempts.incrementAndGet() == 1) throw IOException("temporary read failure")
            object : PosterFaceDetector {
                override fun detect(file: File) = PosterFaceAnalysis(100, 200, emptyList())
                override fun close() = Unit
            }
        }, onFailure = {})

        try {
            assertNull(worker.analyze("first").get(3, SECONDS))
            assertEquals(PosterFaceAnalysis(100, 200, emptyList()), worker.analyze("second").get(3, SECONDS))
            assertEquals(2, attempts.get())
        } finally {
            worker.close()
        }
    }

    @Test
    fun doesNotRetryAfterNativeLinkageFailure() {
        val attempts = AtomicInteger()
        val worker = PosterFaceWorker(createDetector = {
            attempts.incrementAndGet()
            throw UnsatisfiedLinkError("unavailable architecture")
        }, onFailure = {})

        try {
            assertNull(worker.analyze("first").get(3, SECONDS))
            assertNull(worker.analyze("second").get(3, SECONDS))
            assertEquals(1, attempts.get())
        } finally {
            worker.close()
        }
    }

    @Test
    fun closesAfterInFlightDetectionAndSkipsPendingWork() {
        val started = CountDownLatch(1)
        val finished = CountDownLatch(1)
        val released = CountDownLatch(1)
        val calls = AtomicInteger()
        val worker = PosterFaceWorker(createDetector = {
            object : PosterFaceDetector {
                override fun detect(file: File): PosterFaceAnalysis {
                    calls.incrementAndGet()
                    started.countDown()
                    check(finished.await(3, SECONDS))
                    return PosterFaceAnalysis(100, 200, emptyList())
                }

                override fun close() {
                    released.countDown()
                }
            }
        }, onFailure = { throw AssertionError(it) })

        try {
            val inFlight = worker.analyze("started")
            assertTrue(started.await(3, SECONDS))
            val pending = worker.analyze("pending")
            worker.close()
            assertEquals(1L, released.count)
            finished.countDown()

            assertNull(inFlight.get(3, SECONDS))
            assertNull(pending.get(3, SECONDS))
            assertNull(worker.analyze("detached").get(3, SECONDS))
            assertTrue(released.await(3, SECONDS))
            assertEquals(1, calls.get())
        } finally {
            finished.countDown()
            worker.close()
        }
    }

    private fun PosterFaceWorker.analyze(path: String): CompletableFuture<PosterFaceAnalysis?> {
        val reply = CompletableFuture<PosterFaceAnalysis?>()
        detect(File(path)) { reply.complete(it) }
        return reply
    }

    private companion object {
        const val DELTA = 0.00001
    }
}
