package com.example.offline_ai_notepad

import android.os.Build
import java.io.File
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "offline_ai_notepad/onnx_runtime"

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

                    result.success(
                        mapOf(
                            "nativeLibraryLinked" to nativeLinked,
                            "modelExists" to modelExists,
                            "tokenizerExists" to tokenizerExists,
                            "modelPath" to modelFile.absolutePath,
                            "tokenizerPath" to tokenizerFile?.absolutePath,
                            "platform" to "android-${Build.VERSION.SDK_INT}",
                            "ready" to (nativeLinked && modelExists && tokenizerExists),
                            "message" to when {
                                !nativeLinked -> "ONNX Runtime dependency is not available to the native bridge yet."
                                !modelExists -> "Staged ONNX model file was not found on disk."
                                !tokenizerExists -> "Tokenizer asset was expected but not found on disk."
                                else -> "Native ONNX session prerequisites look ready."
                            },
                        ),
                    )
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
