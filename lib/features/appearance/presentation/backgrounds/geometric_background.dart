import 'dart:math';

import 'package:flutter/material.dart';

/// A few large, slowly rotating polygon outlines that gently pulse in scale —
/// a quiet, architectural backdrop. Only a handful of stroked shapes, so it
/// stays cheap.
class GeometricPainter extends CustomPainter {
  GeometricPainter({required this.progress, required this.color})
      : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  static final List<_Shape> _shapes = _build();

  static List<_Shape> _build() {
    final rng = Random(1414213);
    return List.generate(6, (i) {
      return _Shape(
        cx: rng.nextDouble(),
        cy: rng.nextDouble(),
        radius: 0.14 + rng.nextDouble() * 0.20,
        sides: 3 + rng.nextInt(4), // triangle..hexagon
        spin: (rng.nextBool() ? 1 : -1) * (0.4 + rng.nextDouble() * 0.8),
        phase: rng.nextDouble(),
        alpha: 0.06 + rng.nextDouble() * 0.10,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final minSide = min(size.width, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;

    for (final s in _shapes) {
      final center = Offset(s.cx * size.width, s.cy * size.height);
      final pulse = 1.0 + 0.08 * sin(2 * pi * (t + s.phase));
      final r = s.radius * minSide * pulse;
      final rotation = 2 * pi * (t * s.spin + s.phase);

      final path = Path();
      for (var k = 0; k <= s.sides; k++) {
        final a = rotation + k * 2 * pi / s.sides;
        final point = center + Offset(cos(a), sin(a)) * r;
        if (k == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      paint.color = color.withValues(alpha: s.alpha);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant GeometricPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _Shape {
  const _Shape({
    required this.cx,
    required this.cy,
    required this.radius,
    required this.sides,
    required this.spin,
    required this.phase,
    required this.alpha,
  });

  final double cx;
  final double cy;
  final double radius;
  final int sides;
  final double spin;
  final double phase;
  final double alpha;
}
