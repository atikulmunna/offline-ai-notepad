import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/app_background.dart';
import 'geometric_background.dart';
import 'particles_background.dart';
import 'snow_background.dart';
import 'space_background.dart';

/// Paints the animated backdrop behind the notes library.
///
/// Resolves [AppBackground.shuffle] to a concrete style **once per widget
/// lifetime** (stable within an app session), honors the OS "reduce motion"
/// accessibility flag (renders a single static frame instead of animating),
/// and isolates itself in a [RepaintBoundary] so foreground rebuilds (list
/// scrolling, typing) never force the background to repaint.
class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key, required this.background});

  final AppBackground background;

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late AppBackground _resolved;

  @override
  void initState() {
    super.initState();
    _resolved = widget.background.resolveConcrete(Random());
    // A long period keeps motion slow and calm; particle math loops on it.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.background != widget.background) {
      _resolved = widget.background.resolveConcrete(Random());
    }
    _syncTicker();
  }

  void _syncTicker() {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final shouldAnimate = _resolved.isAnimated && !reduceMotion;
    if (shouldAnimate) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_resolved.isAnimated) {
      return const SizedBox.expand();
    }

    final accent = Theme.of(context).extension<AppSurfaces>()!.accent;
    final CustomPainter painter = switch (_resolved) {
      AppBackground.snow => SnowPainter(progress: _controller, color: accent),
      AppBackground.geometric =>
        GeometricPainter(progress: _controller, color: accent),
      AppBackground.space => SpacePainter(progress: _controller, color: accent),
      // particles is the default concrete style.
      _ => ParticlesPainter(progress: _controller, color: accent),
    };

    return RepaintBoundary(
      child: CustomPaint(
        painter: painter,
        size: Size.infinite,
        isComplex: true,
        willChange: true,
      ),
    );
  }
}
