import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import 'voice_capture_controller.dart';

/// Modal sheet that captures speech on-device and returns the recognized text.
///
/// Pops with the trimmed transcript when the user taps "Save note", or with
/// null if dismissed. Starts listening automatically on open.
class VoiceCaptureSheet extends ConsumerStatefulWidget {
  const VoiceCaptureSheet({super.key});

  @override
  ConsumerState<VoiceCaptureSheet> createState() => _VoiceCaptureSheetState();
}

class _VoiceCaptureSheetState extends ConsumerState<VoiceCaptureSheet> {
  @override
  void initState() {
    super.initState();
    // Kick off after the first frame so the provider is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceCaptureControllerProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final state = ref.watch(voiceCaptureControllerProvider);
    final controller = ref.read(voiceCaptureControllerProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: surfaces.cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _MicIndicator(
                    listening: state.status == VoiceStatus.listening,
                    soundLevel: state.soundLevel,
                    accent: surfaces.accent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Voice note',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _statusLabel(state.status),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: surfaces.mutedText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 96, maxHeight: 240),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surfaces.cardFill,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: surfaces.cardBorder),
                ),
                child: SingleChildScrollView(
                  reverse: true,
                  child: _TranscriptBody(state: state, surfaces: surfaces),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: state.status == VoiceStatus.listening
                        ? FilledButton.tonalIcon(
                            onPressed: controller.stop,
                            icon: const Icon(Icons.stop_rounded),
                            label: const Text('Stop'),
                          )
                        : FilledButton.icon(
                            onPressed: state.hasText
                                ? () => Navigator.of(context)
                                    .pop(state.transcript.trim())
                                : null,
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Save note'),
                          ),
                  ),
                ],
              ),
              if (!state.isBusy &&
                  !state.hasText &&
                  state.status != VoiceStatus.unavailable &&
                  state.status != VoiceStatus.error) ...[
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    onPressed: controller.start,
                    icon: const Icon(Icons.mic_rounded, size: 18),
                    label: const Text('Listen again'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(VoiceStatus status) {
    return switch (status) {
      VoiceStatus.idle => 'Getting ready…',
      VoiceStatus.initializing => 'Getting ready…',
      VoiceStatus.listening => 'Listening — speak now',
      VoiceStatus.stopped => 'Stopped. Review and save.',
      VoiceStatus.unavailable => 'Unavailable on this device',
      VoiceStatus.error => 'Something went wrong',
    };
  }
}

class _TranscriptBody extends StatelessWidget {
  const _TranscriptBody({required this.state, required this.surfaces});

  final VoiceCaptureState state;
  final AppSurfaces surfaces;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (state.status == VoiceStatus.unavailable ||
        state.status == VoiceStatus.error) {
      return Text(
        state.errorMessage ?? 'Unavailable.',
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.error),
      );
    }
    if (state.hasText) {
      return Text(
        state.transcript,
        style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
      );
    }
    return Text(
      state.status == VoiceStatus.listening
          ? 'Start talking and your words will appear here.'
          : 'No speech captured yet.',
      style: theme.textTheme.bodyMedium?.copyWith(color: surfaces.mutedText),
    );
  }
}

/// A mic glyph that pulses with the incoming sound level while listening.
class _MicIndicator extends StatelessWidget {
  const _MicIndicator({
    required this.listening,
    required this.soundLevel,
    required this.accent,
  });

  final bool listening;
  final double soundLevel;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // soundLevel is a rough dB-ish value; map it to a small scale bump.
    final level = listening ? (soundLevel.clamp(0, 10) / 10) : 0.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: listening ? 0.18 + level * 0.2 : 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Icon(
        listening ? Icons.mic_rounded : Icons.mic_none_rounded,
        color: accent,
        size: 22,
      ),
    );
  }
}
