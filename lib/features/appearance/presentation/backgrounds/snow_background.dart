import 'dart:math';

import 'package:flutter/material.dart';

/// Falling snow: a particle field that drifts downward with a gentle sideways
/// sway and varied flake sizes. Uses white blended toward the theme accent so
/// it reads on both themes.
class SnowPainter extends CustomPainter {
  SnowPainter({required this.progress, required this.color})
      : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  static const _count = 70;
  static final List<_Flake> _flakes = _build();

  static List<_Flake> _build() {
    final rng = Random(70262026);
    return List.generate(_count, (_) {
      return _Flake(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        radius: 1.0 + rng.nextDouble() * 2.6,
        speed: 0.12 + rng.nextDouble() * 0.30,
        swayAmp: 0.01 + rng.nextDouble() * 0.05,
        phase: rng.nextDouble(),
        alpha: 0.25 + rng.nextDouble() * 0.5,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final flakeColor = Color.lerp(Colors.white, color, 0.25)!;
    final paint = Paint()..style = PaintingStyle.fill;

    for (final f in _flakes) {
      final y = (f.y + t * f.speed) % 1.0;
      final sway = sin(2 * pi * (t * 2 + f.phase)) * f.swayAmp;
      final x = (f.x + sway) % 1.0;
      paint.color = flakeColor.withValues(alpha: f.alpha);
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        f.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SnowPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _Flake {
  const _Flake({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.swayAmp,
    required this.phase,
    required this.alpha,
  });

  final double x;
  final double y;
  final double radius;
  final double speed;
  final double swayAmp;
  final double phase;
  final double alpha;
}
