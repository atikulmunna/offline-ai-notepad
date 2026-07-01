# ONNX Runtime's native code looks up its own Java classes via JNI FindClass
# (e.g. in convertToTensorInfo / convertOrtValueToONNXValue). If R8 renames or
# removes them, that lookup returns null and the app aborts with
# "JNI DETECTED ERROR IN APPLICATION: java_class == null" the first time a
# session runs. Keep the whole package intact.
-keep class ai.onnxruntime.** { *; }
-keepclassmembers class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**
