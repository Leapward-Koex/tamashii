package com.leapwardkoex.tamashii

import androidx.core.content.ContextCompat
import com.google.common.util.concurrent.FutureCallback
import com.google.common.util.concurrent.Futures
import com.google.mlkit.genai.common.DownloadCallback
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.common.GenAiException
import com.google.mlkit.genai.prompt.GenerateContentResponse
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.GenerationConfig
import com.google.mlkit.genai.prompt.java.GenerativeModelFutures
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL_NAME = "com.leapwardkoex.tamashii/gemini_nano"
        private const val METHOD_INFER_SEASON = "inferSeason"
    }

    private var generativeModelFutures: GenerativeModelFutures? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                METHOD_INFER_SEASON -> {
                    val text = call.argument<String>("text")?.trim()
                    if (text.isNullOrEmpty()) {
                        result.error(
                            "invalid_args",
                            "The title text must not be empty.",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    inferSeason(text, result)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        generativeModelFutures?.getGenerativeModel()?.close()
        super.onDestroy()
    }

    private fun inferSeason(
        title: String,
        result: MethodChannel.Result,
    ) {
        val modelFutures = getGenerativeModelFutures()
        Futures.addCallback(
            modelFutures.checkStatus(),
            object : FutureCallback<Int> {
                override fun onSuccess(featureStatus: Int?) {
                    when (featureStatus) {
                        FeatureStatus.AVAILABLE -> runSeasonPrompt(title, result)
                        FeatureStatus.UNAVAILABLE -> {
                            result.error(
                                "feature_unavailable",
                                "Gemini Nano is unavailable on this device. Ensure AI Core and a supported model are available.",
                                null,
                            )
                        }

                        else -> downloadAndRunSeasonPrompt(title, result)
                    }
                }

                override fun onFailure(t: Throwable) {
                    result.error(
                        "status_error",
                        "Failed to check Gemini Nano availability: ${t.message}",
                        null,
                    )
                }
            },
            ContextCompat.getMainExecutor(this),
        )
    }

    private fun downloadAndRunSeasonPrompt(
        title: String,
        result: MethodChannel.Result,
    ) {
        val modelFutures = getGenerativeModelFutures()
        Futures.addCallback(
            modelFutures.download(
                object : DownloadCallback {
                    override fun onDownloadStarted(bytesToDownload: Long) = Unit

                    override fun onDownloadProgress(totalBytesDownloaded: Long) = Unit

                    override fun onDownloadCompleted() = Unit

                    override fun onDownloadFailed(error: GenAiException) = Unit
                },
            ),
            object : FutureCallback<Void> {
                override fun onSuccess(unused: Void?) {
                    runSeasonPrompt(title, result)
                }

                override fun onFailure(t: Throwable) {
                    result.error(
                        "download_error",
                        "Failed to download the Gemini Nano model: ${t.message}",
                        null,
                    )
                }
            },
            ContextCompat.getMainExecutor(this),
        )
    }

    private fun runSeasonPrompt(
        title: String,
        result: MethodChannel.Result,
    ) {
        val prompt = buildSeasonPrompt(title)
        Futures.addCallback(
            getGenerativeModelFutures().generateContent(prompt),
            object : FutureCallback<GenerateContentResponse> {
                override fun onSuccess(response: GenerateContentResponse?) {
                    val text =
                        response
                            ?.candidates
                            ?.firstOrNull()
                            ?.text
                            ?.trim()

                    if (text.isNullOrEmpty()) {
                        result.error(
                            "empty_response",
                            "Gemini Nano returned an empty response.",
                            null,
                        )
                        return
                    }

                    result.success(text)
                }

                override fun onFailure(t: Throwable) {
                    result.error(
                        "inference_error",
                        "Gemini Nano inference failed: ${t.message}",
                        null,
                    )
                }
            },
            ContextCompat.getMainExecutor(this),
        )
    }

    private fun getGenerativeModelFutures(): GenerativeModelFutures {
        generativeModelFutures?.let { return it }

        val config =
            GenerationConfig
                .Builder()
                .build()
        val generativeModel = Generation.getClient(config)
        return GenerativeModelFutures
            .from(generativeModel)
            .also { generativeModelFutures = it }
    }

    private fun buildSeasonPrompt(title: String): String =
        """
        You are extracting season information from an anime or TV show title.
        
        Determine what season the title belongs to.
        Examples:
        - "Show Name S4" -> "Season 04"
        - "Show Name Season 4" -> "Season 04"
        - "Show Name Season 04" -> "Season 04"
        - "Show Name part 4" -> "Season 04"
        - "Show Name" -> "Season 01"
        
        Respond with exactly two lines:
        Season: Season NN or Unknown
        Reason: one short sentence
        
        Title: $title
        """.trimIndent()
}
