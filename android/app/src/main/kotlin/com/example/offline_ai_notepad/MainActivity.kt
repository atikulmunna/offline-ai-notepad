package com.example.offline_ai_notepad

import android.os.Build
import java.io.File
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "offline_ai_notepad/onnx_runtime"
    private val onnxSessionManager = OnnxSessionManager()

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
                    if (modelPath.isNullOrBlank()) {
                        result.error("missing_model_path", "Model path is required.", null)
                        return@setMethodCallHandler
                    }

                    val modelFile = File(modelPath)
                    val tokenizerFile = tokenizerPath?.let { File(it) }
                    val nativeLinked = isOnnxRuntimeLinked()
                    val modelExists = modelFile.exists()
                    val tokenizerExists = tokenizerFile?.exists() ?: true
                    val sessionReady =
                        nativeLinked && modelExists && tokenizerExists &&
                            onnxSessionManager.ensureSummarySession(modelFile.absolutePath)

                    result.success(
                        mapOf(
                            "nativeLibraryLinked" to nativeLinked,
                            "modelExists" to modelExists,
                            "tokenizerExists" to tokenizerExists,
                            "modelPath" to modelFile.absolutePath,
                            "tokenizerPath" to tokenizerFile?.absolutePath,
                            "platform" to "android-${Build.VERSION.SDK_INT}",
                            "ready" to sessionReady,
                            "message" to when {
                                !nativeLinked -> "ONNX Runtime dependency is not available to the native bridge yet."
                                !modelExists -> "Staged ONNX model file was not found on disk."
                                !tokenizerExists -> "Tokenizer asset was expected but not found on disk."
                                !sessionReady -> "ONNX Runtime is linked, but the summary session could not be opened."
                                else -> "Native ONNX summary session opened successfully."
                            },
                        ),
                    )
                }

                "generateSummary" -> {
                    val modelPath = call.argument<String>("modelPath")
                    val title = call.argument<String>("title")
                    val body = call.argument<String>("body")
                    if (modelPath.isNullOrBlank() || body.isNullOrBlank()) {
                        result.error(
                            "missing_arguments",
                            "Both modelPath and body are required.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    val summary = onnxSessionManager.generateSummaryPlaceholder(
                        title = title,
                        body = body,
                        modelPath = modelPath,
                    )
                    if (summary == null) {
                        result.error(
                            "session_unavailable",
                            "ONNX summary session could not be opened for the staged model.",
                            null,
                        )
                    } else {
                        result.success(
                            mapOf(
                                "summary" to summary,
                                "engine" to "android-onnx-placeholder",
                                "message" to "Summary generated through the native ONNX bridge placeholder path.",
                            ),
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
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
