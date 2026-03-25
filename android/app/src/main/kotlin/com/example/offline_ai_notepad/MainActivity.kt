package com.example.offline_ai_notepad

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "offline_ai_notepad/onnx_runtime",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getRuntimeCapability" -> {
                    result.success(
                        mapOf(
                            "bridgeAvailable" to true,
                            "nativeLibraryLinked" to false,
                            "platform" to "android",
                            "message" to "Android ONNX bridge is registered, but the native ONNX runtime library is not linked yet.",
                        ),
                    )
                }

                else -> result.notImplemented()
            }
        }
    }
}
