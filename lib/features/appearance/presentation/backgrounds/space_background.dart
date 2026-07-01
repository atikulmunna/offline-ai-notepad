import 'dart:math';

import 'package:flutter/material.dart';

/// A twinkling starfield with two parallax layers drifting at different speeds —
/// the most dramatic look on true black. Stars are small filled points, so even
/// a few hundred stay inexpensive.
class SpacePainter extends CustomPainter {
  SpacePainter({required this.progress, required this.color})
      : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  static final List<_Star> _stars = _build();

  static List<_Star> _build() {
    final rng = Random(299792458);
    return List.generate(200, (_) {
      final far = rng.nextDouble() < 0.7;
      return _Star(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        radius: far ? 0.5 + rng.nextDouble() * 0.8 : 1.0 + rng.nextDouble() * 1.6,
        drift: far ? 0.015 : 0.04,
        phase: rng.nextDouble(),
        baseAlpha: far ? 0.25 + rng.nextDouble() * 0.35 : 0.5 + rng.nextDouble() * 0.5,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final starColor = Color.lerp(Colors.white, color, 0.15)!;
    final paint = Paint()..style = PaintingStyle.fill;

    for (final s in _stars) {
      // Slow horizontal parallax drift, wrapping around.
      final x = (s.x + t * s.drift) % 1.0;
      final twinkle = 0.6 + 0.4 * sin(2 * pi * (t * 3 + s.phase));
      paint.color = starColor.withValues(alpha: s.baseAlpha * twinkle);
      canvas.drawCircle(
        Offset(x * size.width, s.y * size.height),
        s.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SpacePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _Star {
  const _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.drift,
    required this.phase,
    required this.baseAlpha,
  });

  final double x;
  final double y;
  final double radius;
  final double drift;
  final double phase;
  final double baseAlpha;
}
