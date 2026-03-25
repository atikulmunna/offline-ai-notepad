import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/onnx_runtime_capability.dart';
import '../domain/onnx_contract_inspection.dart';
import '../domain/onnx_session_preparation.dart';
import '../domain/onnx_summary_response.dart';

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
    List<String> inputNames = const [],
    List<String> outputNames = const [],
    int? maxSequenceLength,
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
          'inputNames': inputNames,
          'outputNames': outputNames,
          'maxSequenceLength': maxSequenceLength,
        },
      );

      return OnnxSessionPreparation(
        nativeLibraryLinked: raw?['nativeLibraryLinked'] as bool? ?? false,
        modelExists: raw?['modelExists'] as bool? ?? false,
        tokenizerExists: raw?['tokenizerExists'] as bool? ?? (tokenizerPath == null),
        ready: raw?['ready'] as bool? ?? false,
        platform: raw?['platform'] as String? ?? defaultTargetPlatform.name,
        inputNames: (raw?['inputNames'] as List<dynamic>? ?? const [])
            .map((item) => item as String)
            .toList(growable: false),
        outputNames: (raw?['outputNames'] as List<dynamic>? ?? const [])
            .map((item) => item as String)
            .toList(growable: false),
        maxSequenceLength: raw?['maxSequenceLength'] as int?,
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

  Future<OnnxSummaryResponse?> generateSummary({
    required String modelPath,
    String? title,
    required String body,
    List<String> inputNames = const [],
    List<String> outputNames = const [],
    int? maxSequenceLength,
  }) async {
    if (kIsWeb) {
      return null;
    }

    final channel = _channel ?? _defaultChannel;
    try {
      final raw = await channel.invokeMapMethod<String, dynamic>(
        'generateSummary',
        {
          'modelPath': modelPath,
          'title': title,
          'body': body,
          'inputNames': inputNames,
          'outputNames': outputNames,
          'maxSequenceLength': maxSequenceLength,
        },
      );
      final summary = raw?['summary'] as String?;
      if (summary == null || summary.trim().isEmpty) {
        return null;
      }
      return OnnxSummaryResponse(
        summary: summary,
        engine: raw?['engine'] as String? ?? 'android-onnx',
        usedInputNames: (raw?['usedInputNames'] as List<dynamic>? ?? const [])
            .map((item) => item as String)
            .toList(growable: false),
        usedOutputNames: (raw?['usedOutputNames'] as List<dynamic>? ?? const [])
            .map((item) => item as String)
            .toList(growable: false),
        message: raw?['message'] as String?,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<OnnxContractInspection?> inspectContract({
    required String modelPath,
    List<String> inputNames = const [],
    List<String> outputNames = const [],
    int? maxSequenceLength,
  }) async {
    if (kIsWeb) {
      return null;
    }

    final channel = _channel ?? _defaultChannel;
    try {
      final raw = await channel.invokeMapMethod<String, dynamic>(
        'inspectContract',
        {
          'modelPath': modelPath,
          'inputNames': inputNames,
          'outputNames': outputNames,
          'maxSequenceLength': maxSequenceLength,
        },
      );
      if (raw == null) {
        return null;
      }
      return OnnxContractInspection(
        available: raw['available'] as bool? ?? false,
        matchesManifest: raw['matchesManifest'] as bool? ?? false,
        actualInputNames: (raw['actualInputNames'] as List<dynamic>? ?? const [])
            .map((item) => item as String)
            .toList(growable: false),
        actualOutputNames: (raw['actualOutputNames'] as List<dynamic>? ?? const [])
            .map((item) => item as String)
            .toList(growable: false),
        message: raw['message'] as String?,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
