import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Lifecycle of a single voice-capture session.
enum VoiceStatus { idle, initializing, unavailable, listening, stopped, error }

/// Immutable UI state for the voice-capture sheet.
class VoiceCaptureState {
  const VoiceCaptureState({
    this.status = VoiceStatus.idle,
    this.transcript = '',
    this.soundLevel = 0,
    this.errorMessage,
  });

  final VoiceStatus status;
  final String transcript;
  final double soundLevel;
  final String? errorMessage;

  bool get hasText => transcript.trim().isNotEmpty;
  bool get isBusy =>
      status == VoiceStatus.initializing || status == VoiceStatus.listening;

  VoiceCaptureState copyWith({
    VoiceStatus? status,
    String? transcript,
    double? soundLevel,
    String? errorMessage,
    bool clearError = false,
  }) {
    return VoiceCaptureState(
      status: status ?? this.status,
      transcript: transcript ?? this.transcript,
      soundLevel: soundLevel ?? this.soundLevel,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Drives on-device speech recognition for A4 (Voice → Note).
///
/// Uses the platform's built-in recognizer with `onDevice: true` so captured
/// audio is never sent to a cloud service — consistent with the app's offline,
/// private thesis. If the device has no on-device language installed the
/// session reports [VoiceStatus.unavailable] rather than falling back to the
/// network.
class VoiceCaptureController extends StateNotifier<VoiceCaptureState> {
  VoiceCaptureController() : super(const VoiceCaptureState());

  final SpeechToText _speech = SpeechToText();

  Future<void> start() async {
    if (state.isBusy) {
      return;
    }
    state = state.copyWith(
      status: VoiceStatus.initializing,
      transcript: '',
      clearError: true,
    );

    final bool available;
    try {
      available = await _speech.initialize(
        onError: (error) {
          if (!mounted) {
            return;
          }
          state = state.copyWith(
            status: VoiceStatus.error,
            errorMessage: 'Recognition error: ${error.errorMsg}',
          );
        },
        onStatus: (status) {
          if (!mounted) {
            return;
          }
          if ((status == 'done' || status == 'notListening') &&
              state.status == VoiceStatus.listening) {
            state = state.copyWith(status: VoiceStatus.stopped);
          }
        },
      );
    } catch (_) {
      if (mounted) {
        state = state.copyWith(
          status: VoiceStatus.unavailable,
          errorMessage: _unavailableMessage,
        );
      }
      return;
    }

    if (!mounted) {
      return;
    }
    if (!available) {
      state = state.copyWith(
        status: VoiceStatus.unavailable,
        errorMessage: _unavailableMessage,
      );
      return;
    }

    state = state.copyWith(status: VoiceStatus.listening);
    await _speech.listen(
      onResult: _onResult,
      onSoundLevelChange: (level) {
        if (mounted) {
          state = state.copyWith(soundLevel: level);
        }
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        onDevice: true,
        cancelOnError: true,
        pauseFor: const Duration(seconds: 4),
      ),
    );
  }

  void _onResult(SpeechRecognitionResult result) {
    if (!mounted) {
      return;
    }
    state = state.copyWith(transcript: result.recognizedWords);
  }

  Future<void> stop() async {
    if (state.status == VoiceStatus.listening) {
      await _speech.stop();
      if (mounted) {
        state = state.copyWith(status: VoiceStatus.stopped);
      }
    }
  }

  static const _unavailableMessage =
      'On-device speech recognition is unavailable. Grant microphone access and '
      'install an offline language for your keyboard/voice input, then try again.';

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }
}

final voiceCaptureControllerProvider = StateNotifierProvider.autoDispose<
    VoiceCaptureController, VoiceCaptureState>((ref) {
  return VoiceCaptureController();
});
