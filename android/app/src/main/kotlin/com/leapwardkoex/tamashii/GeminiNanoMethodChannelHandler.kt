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
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class GeminiNanoMethodChannelHandler(
    private val activity: FlutterActivity,
) {
    companion object {
        private const val CHANNEL_NAME = "com.leapwardkoex.tamashii/gemini_nano"
        private const val METHOD_GENERATE_TEXT = "generateText"
        private const val METHOD_GET_MODEL_CATALOG = "getModelCatalog"
        private const val SYSTEM_DEFAULT_MODEL = "system_default"
    }

    private var generativeModelFutures: GenerativeModelFutures? = null

    fun configure(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler(::handleMethodCall)
    }

    fun dispose() {
        generativeModelFutures?.getGenerativeModel()?.close()
        generativeModelFutures = null
    }

    private fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            METHOD_GET_MODEL_CATALOG -> getModelCatalog(result)
            METHOD_GENERATE_TEXT -> {
                val prompt = call.argument<String>("prompt")?.trim()
                if (prompt.isNullOrEmpty()) {
                    result.error(
                        "invalid_args",
                        "The prompt must not be empty.",
                        null,
                    )
                    return
                }

                generateText(
                    prompt = prompt,
                    result = result,
                )
            }

            else -> result.notImplemented()
        }
    }

    private fun getModelCatalog(result: MethodChannel.Result) {
        val modelFutures = getGenerativeModelFutures()
        Futures.addCallback(
            modelFutures.checkStatus(),
            object : FutureCallback<Int> {
                override fun onSuccess(featureStatus: Int?) {
                    val status = featureStatus ?: FeatureStatus.UNAVAILABLE
                    resolveActiveModel(
                        featureStatus = status,
                    ) { activeModel ->
                        val availableModels =
                            if (status == FeatureStatus.UNAVAILABLE) {
                                emptyList()
                            } else {
                                listOf(activeModel ?: SYSTEM_DEFAULT_MODEL)
                            }

                        result.success(
                            mapOf(
                                "featureStatus" to status,
                                "activeModel" to activeModel,
                                "availableModels" to availableModels,
                            ),
                        )
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
            ContextCompat.getMainExecutor(activity),
        )
    }

    private fun generateText(
        prompt: String,
        result: MethodChannel.Result,
    ) {
        val modelFutures = getGenerativeModelFutures()
        Futures.addCallback(
            modelFutures.checkStatus(),
            object : FutureCallback<Int> {
                override fun onSuccess(featureStatus: Int?) {
                    when (featureStatus) {
                        FeatureStatus.AVAILABLE -> {
                            runGeneration(
                                prompt = prompt,
                                result = result,
                            )
                        }

                        FeatureStatus.UNAVAILABLE -> {
                            result.error(
                                "feature_unavailable",
                                "Gemini Nano is unavailable on this device. Ensure AI Core and a supported model are available.",
                                null,
                            )
                        }

                        else -> {
                            downloadAndRunGeneration(
                                prompt = prompt,
                                result = result,
                            )
                        }
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
            ContextCompat.getMainExecutor(activity),
        )
    }

    private fun downloadAndRunGeneration(
        prompt: String,
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
                    runGeneration(
                        prompt = prompt,
                        result = result,
                    )
                }

                override fun onFailure(t: Throwable) {
                    result.error(
                        "download_error",
                        "Failed to download the Gemini Nano model: ${t.message}",
                        null,
                    )
                }
            },
            ContextCompat.getMainExecutor(activity),
        )
    }

    private fun runGeneration(
        prompt: String,
        result: MethodChannel.Result,
    ) {
        resolveActiveModel(
            featureStatus = FeatureStatus.AVAILABLE,
        ) { activeModel ->
            val resolvedModel = activeModel ?: SYSTEM_DEFAULT_MODEL

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

                        result.success(
                            mapOf(
                                "text" to text,
                                "modelUsed" to resolvedModel,
                            ),
                        )
                    }

                    override fun onFailure(t: Throwable) {
                        result.error(
                            "inference_error",
                            "Gemini Nano inference failed: ${t.message}",
                            null,
                        )
                    }
                },
                ContextCompat.getMainExecutor(activity),
            )
        }
    }

    private fun resolveActiveModel(
        featureStatus: Int,
        onResolved: (String?) -> Unit,
    ) {
        if (featureStatus == FeatureStatus.UNAVAILABLE) {
            onResolved(null)
            return
        }

        Futures.addCallback(
            getGenerativeModelFutures().getBaseModelName(),
            object : FutureCallback<String> {
                override fun onSuccess(modelName: String?) {
                    onResolved(modelName?.trim()?.takeIf { it.isNotEmpty() })
                }

                override fun onFailure(t: Throwable) {
                    onResolved(null)
                }
            },
            ContextCompat.getMainExecutor(activity),
        )
    }

    private fun getGenerativeModelFutures(): GenerativeModelFutures {
        generativeModelFutures?.let { return it }

        val generativeModel =
            Generation.getClient(
                GenerationConfig
                    .Builder()
                    .build(),
            )
        return GenerativeModelFutures
            .from(generativeModel)
            .also { generativeModelFutures = it }
    }
}
