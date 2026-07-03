package com.atikulmunna.nativenote

import android.os.Build
import android.os.Handler
import android.os.Looper
import java.io.File
import java.util.concurrent.Executors
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "nativenote/onnx_runtime"
    private val onnxSessionManager = OnnxSessionManager()

    // ONNX inference (a full encoder pass plus up to ~72 sequential decoder
    // steps) is far too heavy to run on the platform thread — on lower-end CPUs
    // it blocks the UI for tens of seconds and the app freezes/ANRs. Run every
    // native call on a single background thread (single-threaded so the shared
    // OrtEnvironment/OrtSession state stays serialized and thread-safe), then
    // marshal the MethodChannel result back onto the main thread.
    private val nativeExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private fun onBackground(result: MethodChannel.Result, block: () -> Unit) {
        nativeExecutor.execute {
            try {
                block()
            } catch (t: Throwable) {
                postError(result, "native_error", t.message ?: "Native ONNX call failed.")
            }
        }
    }

    private fun postSuccess(result: MethodChannel.Result, value: Any?) {
        mainHandler.post { result.success(value) }
    }

    private fun postError(result: MethodChannel.Result, code: String, message: String) {
        mainHandler.post { result.error(code, message, null) }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getRuntimeCapability" -> {
                    val nativeLinked = isOnnxRuntimeLinked()
                    result.success(
                        mapOf(
                            "bridgeAvailable" to true,
                            "nativeLibraryLinked" to nativeLinked,
                            "platform" to "android",
                            "message" to if (nativeLinked) {
                                "Android ONNX bridge is registered and the ONNX Runtime Android package is available."
                            } else {
                                "Android ONNX bridge is registered, but the ONNX Runtime Android package has not been linked yet."
                            },
                        ),
                    )
                }

                "prepareSession" -> {
                    val modelPath = call.argument<String>("modelPath")
                    val tokenizerPath = call.argument<String>("tokenizerPath")
                    val inputNames = call.argument<List<String>>("inputNames") ?: emptyList()
                    val outputNames = call.argument<List<String>>("outputNames") ?: emptyList()
                    val maxSequenceLength = call.argument<Int>("maxSequenceLength")
                    if (modelPath.isNullOrBlank()) {
                        result.error("missing_model_path", "Model path is required.", null)
                        return@setMethodCallHandler
                    }

                    onBackground(result) {
                        val modelFile = File(modelPath)
                        val encoderFile = File(modelFile.parentFile, "encoder_model.onnx")
                        val tokenizerFile = tokenizerPath?.let { File(it) }
                        val nativeLinked = isOnnxRuntimeLinked()
                        val modelExists = modelFile.exists()
                        val encoderExists = encoderFile.exists()
                        val tokenizerExists = tokenizerFile?.exists() ?: true
                        val sessionReady =
                            nativeLinked && modelExists && encoderExists && tokenizerExists &&
                                onnxSessionManager.ensureSummarySession(
                                    modelFile.absolutePath,
                                    inputNames,
                                    outputNames,
                                    maxSequenceLength,
                                )

                        postSuccess(
                            result,
                            mapOf(
                                "nativeLibraryLinked" to nativeLinked,
                                "modelExists" to modelExists,
                                "encoderExists" to encoderExists,
                                "tokenizerExists" to tokenizerExists,
                                "modelPath" to modelFile.absolutePath,
                                "encoderModelPath" to encoderFile.absolutePath,
                                "tokenizerPath" to tokenizerFile?.absolutePath,
                                "platform" to "android-${Build.VERSION.SDK_INT}",
                                "inputNames" to inputNames,
                                "outputNames" to outputNames,
                                "maxSequenceLength" to maxSequenceLength,
                                "ready" to sessionReady,
                                "message" to when {
                                    !nativeLinked -> "ONNX Runtime dependency is not available to the native bridge yet."
                                    !modelExists -> "Staged ONNX model file was not found on disk."
                                    !encoderExists -> "Paired encoder_model.onnx was not found beside the staged decoder model."
                                    !tokenizerExists -> "Tokenizer asset was expected but not found on disk."
                                    !sessionReady -> "ONNX Runtime is linked, but the summary session could not be opened."
                                    else -> "Native ONNX encoder-decoder summary sessions opened successfully."
                                },
                            ),
                        )
                    }
                }

                "generateSummary" -> {
                    val modelPath = call.argument<String>("modelPath")
                    val tokenizerPath = call.argument<String>("tokenizerPath")
                    val title = call.argument<String>("title")
                    val body = call.argument<String>("body")
                    val inputNames = call.argument<List<String>>("inputNames") ?: emptyList()
                    val outputNames = call.argument<List<String>>("outputNames") ?: emptyList()
                    val maxSequenceLength = call.argument<Int>("maxSequenceLength")
                    val padTokenId = call.argument<Int>("padTokenId")
                    val unkTokenId = call.argument<Int>("unkTokenId")
                    val bosTokenId = call.argument<Int>("bosTokenId")
                    val eosTokenId = call.argument<Int>("eosTokenId")
                    if (modelPath.isNullOrBlank() || body.isNullOrBlank()) {
                        result.error(
                            "missing_arguments",
                            "Both modelPath and body are required.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    onBackground(result) {
                        val summary = onnxSessionManager.generateSummary(
                            title = title,
                            body = body,
                            modelPath = modelPath,
                            tokenizerPath = tokenizerPath,
                            inputNames = inputNames,
                            outputNames = outputNames,
                            maxSequenceLength = maxSequenceLength,
                            padTokenId = padTokenId,
                            unkTokenId = unkTokenId,
                            bosTokenId = bosTokenId,
                            eosTokenId = eosTokenId,
                        )
                        if (summary == null) {
                            postError(
                                result,
                                "session_unavailable",
                                "ONNX summary session could not be opened for the staged model.",
                            )
                        } else {
                            postSuccess(
                                result,
                                mapOf(
                                    "summary" to summary,
                                    "engine" to "android-onnx-greedy",
                                    "usedInputNames" to inputNames,
                                    "usedOutputNames" to outputNames,
                                    "message" to "Summary generated through the native ONNX encoder-decoder greedy path.",
                                ),
                            )
                        }
                    }
                }

                "generateEmbedding" -> {
                    val modelPath = call.argument<String>("modelPath")
                    val tokenizerPath = call.argument<String>("tokenizerPath")
                    val text = call.argument<String>("text")
                    val maxSequenceLength = call.argument<Int>("maxSequenceLength")
                    if (modelPath.isNullOrBlank() || text.isNullOrBlank()) {
                        result.error(
                            "missing_arguments",
                            "Both modelPath and text are required.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    onBackground(result) {
                        val embedding = onnxSessionManager.generateEmbedding(
                            text = text,
                            modelPath = modelPath,
                            tokenizerPath = tokenizerPath,
                            maxSequenceLength = maxSequenceLength,
                        )
                        if (embedding == null) {
                            postError(
                                result,
                                "embedding_unavailable",
                                "ONNX embedding session could not be opened for the staged model.",
                            )
                        } else {
                            postSuccess(
                                result,
                                mapOf(
                                    "embedding" to embedding.map { it.toDouble() },
                                    "dim" to embedding.size,
                                    "engine" to "android-onnx-embedding",
                                    "message" to "Embedding generated through the native ONNX mean-pooled encoder path.",
                                ),
                            )
                        }
                    }
                }

                "inspectContract" -> {
                    val modelPath = call.argument<String>("modelPath")
                    val inputNames = call.argument<List<String>>("inputNames") ?: emptyList()
                    val outputNames = call.argument<List<String>>("outputNames") ?: emptyList()
                    val maxSequenceLength = call.argument<Int>("maxSequenceLength")
                    if (modelPath.isNullOrBlank()) {
                        result.error(
                            "missing_model_path",
                            "Model path is required for contract inspection.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    onBackground(result) {
                        postSuccess(
                            result,
                            onnxSessionManager.inspectSummaryContract(
                                modelPath = modelPath,
                                expectedInputNames = inputNames,
                                expectedOutputNames = outputNames,
                                maxSequenceLength = maxSequenceLength,
                            ),
                        )
                    }
                }

                "previewTokenization" -> {
                    val modelPath = call.argument<String>("modelPath")
                    val tokenizerPath = call.argument<String>("tokenizerPath")
                    val title = call.argument<String>("title")
                    val body = call.argument<String>("body")
                    val maxSequenceLength = call.argument<Int>("maxSequenceLength")
                    val padTokenId = call.argument<Int>("padTokenId")
                    val unkTokenId = call.argument<Int>("unkTokenId")
                    val bosTokenId = call.argument<Int>("bosTokenId")
                    val eosTokenId = call.argument<Int>("eosTokenId")
                    if (modelPath.isNullOrBlank() || body.isNullOrBlank()) {
                        result.error(
                            "missing_arguments",
                            "Model path and body are required for tokenization preview.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    onBackground(result) {
                        postSuccess(
                            result,
                            onnxSessionManager.previewTokenization(
                                modelPath = modelPath,
                                tokenizerPath = tokenizerPath,
                                title = title,
                                body = body,
                                maxSequenceLength = maxSequenceLength,
                                padTokenId = padTokenId,
                                unkTokenId = unkTokenId,
                                bosTokenId = bosTokenId,
                                eosTokenId = eosTokenId,
                            ),
                        )
                    }
                }

                "inspectTokenizer" -> {
                    val tokenizerPath = call.argument<String>("tokenizerPath")
                    if (tokenizerPath.isNullOrBlank()) {
                        result.error(
                            "missing_tokenizer_path",
                            "Tokenizer path is required for tokenizer inspection.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    onBackground(result) {
                        postSuccess(result, onnxSessionManager.inspectTokenizer(tokenizerPath))
                    }
                }

                "previewRun" -> {
                    val modelPath = call.argument<String>("modelPath")
                    val tokenizerPath = call.argument<String>("tokenizerPath")
                    val title = call.argument<String>("title")
                    val body = call.argument<String>("body")
                    val inputNames = call.argument<List<String>>("inputNames") ?: emptyList()
                    val outputNames = call.argument<List<String>>("outputNames") ?: emptyList()
                    val maxSequenceLength = call.argument<Int>("maxSequenceLength")
                    val padTokenId = call.argument<Int>("padTokenId")
                    val unkTokenId = call.argument<Int>("unkTokenId")
                    val bosTokenId = call.argument<Int>("bosTokenId")
                    val eosTokenId = call.argument<Int>("eosTokenId")
                    if (modelPath.isNullOrBlank() || body.isNullOrBlank()) {
                        result.error(
                            "missing_arguments",
                            "Model path and body are required for run preview.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    onBackground(result) {
                        postSuccess(
                            result,
                            onnxSessionManager.previewRun(
                                modelPath = modelPath,
                                tokenizerPath = tokenizerPath,
                                title = title,
                                body = body,
                                inputNames = inputNames,
                                outputNames = outputNames,
                                maxSequenceLength = maxSequenceLength,
                                padTokenId = padTokenId,
                                unkTokenId = unkTokenId,
                                bosTokenId = bosTokenId,
                                eosTokenId = eosTokenId,
                            ),
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        nativeExecutor.shutdownNow()
        super.onDestroy()
    }

    private fun isOnnxRuntimeLinked(): Boolean {
        return try {
            Class.forName("ai.onnxruntime.OrtEnvironment")
            true
        } catch (_: ClassNotFoundException) {
            false
        }
    }
}
