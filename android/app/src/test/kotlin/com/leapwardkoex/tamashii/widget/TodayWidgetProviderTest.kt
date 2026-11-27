package com.leapwardkoex.tamashii.widget

import android.app.Application
import android.appwidget.AppWidgetHostView
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import android.widget.ListView
import android.widget.ProgressBar
import android.widget.RemoteViews
import android.widget.TextView
import com.leapwardkoex.tamashii.R
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import org.robolectric.shadow.api.Shadow
import org.robolectric.util.ReflectionHelpers.ClassParameter

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [31], application = Application::class, qualifiers = "en-rUS-mdpi")
class TodayWidgetProviderTest {
    private val app: Application get() = RuntimeEnvironment.getApplication()
    private val day = LocalDate.of(2026, 11, 27)
    private val ready = TodayWidgetRow("Night Ferry", TodayWidgetState.READY, "Night Ferry-09", "09")
    private val expected = TodayWidgetRow("Glass Garden", TodayWidgetState.EXPECTED)
    private val active = ready.copy(state = TodayWidgetState.DOWNLOADING, progress = 37)

    private fun inflate(content: TodayWidgetContent, tall: Boolean): View {
        val host = AppWidgetHostView(app)
        val root = TodayWidgetProvider.render(app, content, tall).apply(app, host)
        host.addView(root)
        val width = View.MeasureSpec.makeMeasureSpec(420, View.MeasureSpec.EXACTLY)
        val height = View.MeasureSpec.makeMeasureSpec(if (tall) 500 else 145, View.MeasureSpec.EXACTLY)
        host.measure(width, height)
        host.layout(0, 0, 420, if (tall) 500 else 145)
        return root
    }

    private fun View.list(): ListView = findViewById(R.id.widget_list)
    private fun View.text(id: Int) = findViewById<TextView>(id).text.toString()
    private fun View.visible(id: Int) = findViewById<View>(id).visibility == View.VISIBLE

    @Test
    fun resizingTheHostInBothDirectionsSwitchesLayoutsAndPreservesAllRows() {
        val content = TodayWidgetContent(day, listOf(expected, ready))
        val host = AppWidgetHostView(app)
        // Robolectric's host shortcut inflates getLayoutId(), bypassing Android 12's size map.
        Shadow.directlyOn<Unit, AppWidgetHostView>(host, AppWidgetHostView::class.java, "updateAppWidget",
            ClassParameter.from(RemoteViews::class.java, TodayWidgetProvider.responsive(app, content)))
        for ((height, tall) in listOf(145 to false, 300 to true, 150 to false)) {
            host.measure(View.MeasureSpec.makeMeasureSpec(360, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY))
            host.layout(0, 0, 360, height)
            assertEquals(tall, host.text(R.id.widget_title) == app.getString(R.string.today_widget_title))
            assertEquals(if (tall) 4 else 2, host.list().adapter.count)
        }
    }

    @Test
    fun agendaHasLabeledDownloadAndTheTemplateReceivesTheExactEpisodeAndDate() {
        val agenda = inflate(TodayWidgetContent(day, listOf(expected, ready)), false)
        assertTrue(agenda.text(R.id.widget_title).contains("Friday"))
        val list = agenda.list()
        assertEquals(2, list.adapter.count)
        val first = list.getChildAt(0)
        assertEquals("Night Ferry", first.text(R.id.widget_series))
        assertTrue(first.visible(R.id.widget_button_label))
        assertFalse(first.visible(R.id.widget_art))
        first.findViewById<View>(R.id.widget_ready_button).performClick()
        val sent = shadowOf(app).broadcastIntents.last { it.action?.endsWith(".DOWNLOAD") == true }
        assertEquals(ready.episodeKey, sent.getStringExtra("episodeKey"))
        assertEquals(day.toString(), sent.getStringExtra("date"))
        assertEquals(TodayWidgetProvider::class.java.name, sent.component?.className)
    }

    @Test
    fun activeDownloadFillsTheWholePillOrRingAtRealTransferPercent() {
        for (tall in listOf(false, true)) {
            val root = inflate(TodayWidgetContent(day, listOf(active)), tall)
            val list = root.list()
            val row = list.adapter.getView(if (tall) 1 else 0, null, list)
            val id = if (tall) R.id.widget_ring else R.id.widget_bar
            val bar = row.findViewById<ProgressBar>(id)
            assertEquals(View.VISIBLE, bar.visibility)
            assertFalse(bar.isIndeterminate)
            assertEquals(37, bar.progress)
            assertEquals("37%", row.text(R.id.widget_percent))
            assertFalse(row.visible(R.id.widget_ready_button))
            assertTrue(row.findViewById<View>(R.id.widget_action).contentDescription.contains("Ep 09"))
        }
    }

    @Test
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun progressDrawablesPaintTheActualFractionOfTheBarAndRing() {
        fun painted(tall: Boolean, width: Int, height: Int): Bitmap {
            val list = inflate(TodayWidgetContent(day, listOf(active.copy(progress = 25))), tall).list()
            val row = list.adapter.getView(if (tall) 1 else 0, null, list)
            val progress = row.findViewById<ProgressBar>(if (tall) R.id.widget_ring else R.id.widget_bar)
            val image = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            progress.progressDrawable.setBounds(0, 0, width, height)
            progress.progressDrawable.draw(Canvas(image))
            return image
        }
        val bar = painted(false, 100, 48)
        assertEquals(app.getColor(R.color.widget_progress), bar.getPixel(12, 24))
        assertEquals(app.getColor(R.color.widget_track), bar.getPixel(75, 24))
        val ring = painted(true, 44, 44)
        assertEquals(app.getColor(R.color.widget_blue), ring.getPixel(36, 8))
        assertEquals(app.getColor(R.color.widget_track), ring.getPixel(8, 36))
    }

    @Test
    fun inboxGroupsReadyTransfersAndExpectedAndShowsIndeterminateOnlyWhileWorking() {
        val content = TodayWidgetContent(day, listOf(expected, ready.copy(state = TodayWidgetState.QUEUED), ready.copy(episodeKey = "Night Ferry-10", episode = "10")))
        val list = inflate(content, true).list()
        assertEquals(6, list.adapter.count)
        fun row(index: Int) = list.adapter.getView(index, null, list)
        assertEquals("Ready to download", row(0).text(R.id.widget_section))
        assertTrue(row(1).visible(R.id.widget_art))
        assertEquals("In progress", row(2).text(R.id.widget_section))
        assertTrue(row(3).visible(R.id.widget_spinner))
        assertEquals("Expected today", row(4).text(R.id.widget_section))
        assertFalse(row(5).visible(R.id.widget_action))
        for (state in listOf(TodayWidgetState.WAITING, TodayWidgetState.PAUSED)) {
            val action = ready.copy(state = state).action()
            assertFalse(action.indeterminate)
            assertFalse(action.canDownload)
        }
    }

    @Test
    fun quietDayAndSetupRemainActionableWithoutAReleaseButton() {
        val empty = inflate(TodayWidgetContent(day, emptyList(), nextUp = "Night Ferry on Saturday"), false)
        assertFalse(empty.visible(R.id.widget_list))
        assertTrue(empty.text(R.id.widget_empty_hint).contains("Saturday"))
        val firstRun = inflate(TodayWidgetContent(day, emptyList(), initialized = false), true)
        assertTrue(firstRun.text(R.id.widget_empty_hint).contains("Open Tamashii"))
        val setup = inflate(TodayWidgetContent(day, listOf(ready.copy(state = TodayWidgetState.SETUP))), false)
        assertTrue(setup.visible(R.id.widget_setup))
        assertFalse(setup.list().getChildAt(0).visible(R.id.widget_action))
        assertTrue(setup.findViewById<View>(R.id.widget_setup).performClick())
        assertNotNull(shadowOf(app).nextStartedActivity)
    }

    @Test
    fun numbersAreClampedAndClosedEpisodeStatesDoNotOfferDownload() {
        assertEquals(0, active.copy(progress = -5).action().percent)
        assertEquals(100, active.copy(progress = 120).action().percent)
        for (state in TodayWidgetState.entries - setOf(TodayWidgetState.READY, TodayWidgetState.FAILED)) {
            assertFalse(ready.copy(state = state).action().canDownload)
        }
        assertFalse(ready.copy(episodeKey = null).action().canDownload)
        assertTrue(ready.copy(state = TodayWidgetState.FAILED).action().canDownload)
    }

    @Test
    fun artworkAcceptsRelativeAndHttpsCoversAndSkipsUnavailablePaths() {
        assertEquals("https://subsplease.org/media/night.jpg", TodayWidgetArtwork.resolvedUrl("media/night.jpg"))
        assertEquals("https://example.com/cover.jpg", TodayWidgetArtwork.resolvedUrl("https://example.com/cover.jpg"))
        for (path in listOf(null, "", "file:///tmp/cover", "%%%")) {
            assertEquals(null, TodayWidgetArtwork.resolvedUrl(path))
        }
    }
}
