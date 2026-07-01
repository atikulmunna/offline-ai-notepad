import 'dart:math';

import 'package:flutter/material.dart';

/// Softly drifting glowing dots — the cheapest, calmest background and the
/// default. Particle specs are generated once (deterministically) and animated
/// procedurally, so each frame only issues draw calls with no allocation.
class ParticlesPainter extends CustomPainter {
  ParticlesPainter({required this.progress, required this.color})
      : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  static const _count = 46;
  static final List<_Particle> _particles = _build();

  static List<_Particle> _build() {
    final rng = Random(20260702);
    return List.generate(_count, (_) {
      return _Particle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        radius: 1.2 + rng.nextDouble() * 2.8,
        speed: 0.05 + rng.nextDouble() * 0.22,
        drift: (rng.nextDouble() - 0.5) * 0.06,
        phase: rng.nextDouble(),
        alpha: 0.10 + rng.nextDouble() * 0.32,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in _particles) {
      // Drift slowly upward, wrapping at the top; sway sideways with a sine.
      final y = (p.y - t * p.speed) % 1.0;
      final sway = sin(2 * pi * (t + p.phase)) * p.drift;
      final x = (p.x + sway) % 1.0;
      final center = Offset(x * size.width, y * size.height);
      // Twinkle the alpha a touch so the field feels alive.
      final flicker = 0.75 + 0.25 * sin(2 * pi * (t * 2 + p.phase));
      paint.color = color.withValues(alpha: p.alpha * flicker);
      canvas.drawCircle(center, p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticlesPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _Particle {
  const _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.drift,
    required this.phase,
    required this.alpha,
  });

  final double x;
  final double y;
  final double radius;
  final double speed;
  final double drift;
  final double phase;
  final double alpha;
}
