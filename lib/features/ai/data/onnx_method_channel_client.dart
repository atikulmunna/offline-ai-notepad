import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/onnx_runtime_capability.dart';
import '../domain/onnx_session_preparation.dart';

class OnnxMethodChannelClient {
  const OnnxMethodChannelClient({
    MethodChannel? channel,
  }) : _channel = channel;

  static const _defaultChannel = MethodChannel(
    'offline_ai_notepad/onnx_runtime',
  );

  final MethodChannel? _channel;

  Future<OnnxRuntimeCapability> getCapability() async {
    if (kIsWeb) {
      return const OnnxRuntimeCapability(
        bridgeAvailable: false,
        nativeLibraryLinked: false,
        platform: 'web',
        message: 'Method channels are unavailable on web.',
      );
    }

    final channel = _channel ?? _defaultChannel;
    try {
      final raw = await channel.invokeMapMethod<String, dynamic>(
        'getRuntimeCapability',
      );
      if (raw == null) {
        return const OnnxRuntimeCapability(
          bridgeAvailable: true,
          nativeLibraryLinked: false,
          platform: 'unknown',
          message: 'No capability payload returned.',
        );
      }

      return OnnxRuntimeCapability(
        bridgeAvailable: raw['bridgeAvailable'] as bool? ?? true,
        nativeLibraryLinked: raw['nativeLibraryLinked'] as bool? ?? false,
        platform: raw['platform'] as String? ?? defaultTargetPlatform.name,
        message: raw['message'] as String?,
      );
    } on MissingPluginException {
      return OnnxRuntimeCapability(
        bridgeAvailable: false,
        nativeLibraryLinked: false,
        platform: defaultTargetPlatform.name,
        message: 'Native ONNX bridge is not registered on this platform yet.',
      );
    } on PlatformException catch (error) {
      return OnnxRuntimeCapability(
        bridgeAvailable: true,
        nativeLibraryLinked: false,
        platform: defaultTargetPlatform.name,
        message: error.message ?? error.code,
      );
    }
  }

  Future<OnnxSessionPreparation> prepareSession({
    required String modelPath,
    String? tokenizerPath,
  }) async {
    if (kIsWeb) {
      return const OnnxSessionPreparation(
        nativeLibraryLinked: false,
        modelExists: false,
        tokenizerExists: false,
        ready: false,
        platform: 'web',
        message: 'Native ONNX sessions are unavailable on web.',
      );
    }

    final channel = _channel ?? _defaultChannel;
    try {
      final raw = await channel.invokeMapMethod<String, dynamic>(
        'prepareSession',
        {
          'modelPath': modelPath,
          'tokenizerPath': tokenizerPath,
        },
      );

      return OnnxSessionPreparation(
        nativeLibraryLinked: raw?['nativeLibraryLinked'] as bool? ?? false,
        modelExists: raw?['modelExists'] as bool? ?? false,
        tokenizerExists: raw?['tokenizerExists'] as bool? ?? (tokenizerPath == null),
        ready: raw?['ready'] as bool? ?? false,
        platform: raw?['platform'] as String? ?? defaultTargetPlatform.name,
        modelPath: raw?['modelPath'] as String?,
        tokenizerPath: raw?['tokenizerPath'] as String?,
        message: raw?['message'] as String?,
      );
    } on MissingPluginException {
      return OnnxSessionPreparation(
        nativeLibraryLinked: false,
        modelExists: false,
        tokenizerExists: false,
        ready: false,
        platform: defaultTargetPlatform.name,
        message: 'Native ONNX bridge is not registered on this platform yet.',
      );
    } on PlatformException catch (error) {
      return OnnxSessionPreparation(
        nativeLibraryLinked: false,
        modelExists: false,
        tokenizerExists: false,
        ready: false,
        platform: defaultTargetPlatform.name,
        message: error.message ?? error.code,
      );
    }
  }
}
