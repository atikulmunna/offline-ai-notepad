import 'dart:math';

import 'package:flutter/material.dart';

/// Falling snow drawn as real six-armed snowflakes: they drift downward with a
/// gentle sideways sway and a slow spin, and the larger flakes grow little
/// branches so they read as crystals rather than dots. Uses white blended
/// toward the theme accent so it reads on both themes.
class SnowPainter extends CustomPainter {
  SnowPainter({required this.progress, required this.color})
      : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  static const _count = 55;
  static final List<_Flake> _flakes = _build();

  static List<_Flake> _build() {
    final rng = Random(70262026);
    return List.generate(_count, (_) {
      return _Flake(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        // Arm length in logical pixels.
        radius: 2.5 + rng.nextDouble() * 7.0,
        speed: 0.10 + rng.nextDouble() * 0.26,
        swayAmp: 0.01 + rng.nextDouble() * 0.05,
        phase: rng.nextDouble(),
        alpha: 0.30 + rng.nextDouble() * 0.5,
        baseAngle: rng.nextDouble() * pi,
        spin: (rng.nextBool() ? 1 : -1) * (0.3 + rng.nextDouble() * 0.7),
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final flakeColor = Color.lerp(Colors.white, color, 0.25)!;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.1;

    for (final f in _flakes) {
      final y = (f.y + t * f.speed) % 1.0;
      final sway = sin(2 * pi * (t * 2 + f.phase)) * f.swayAmp;
      final x = (f.x + sway) % 1.0;

      canvas.save();
      canvas.translate(x * size.width, y * size.height);
      canvas.rotate(f.baseAngle + 2 * pi * t * f.spin);
      paint.color = flakeColor.withValues(alpha: f.alpha);
      _drawFlake(canvas, paint, f.radius, detailed: f.radius > 5.0);
      canvas.restore();
    }
  }

  void _drawFlake(Canvas canvas, Paint paint, double r, {required bool detailed}) {
    for (var i = 0; i < 6; i++) {
      final a = i * pi / 3;
      final dir = Offset(cos(a), sin(a));
      canvas.drawLine(Offset.zero, dir * r, paint);
      if (!detailed) {
        continue;
      }
      // Two pairs of little branches partway along each arm.
      for (final along in const [0.5, 0.78]) {
        final base = dir * (r * along);
        final branchLen = r * 0.24;
        for (final sign in const [1.0, -1.0]) {
          final ba = a + sign * (pi / 4);
          final branch = Offset(cos(ba), sin(ba)) * branchLen;
          canvas.drawLine(base, base + branch, paint);
        }
      }
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
    required this.baseAngle,
    required this.spin,
  });

  final double x;
  final double y;
  final double radius;
  final double speed;
  final double swayAmp;
  final double phase;
  final double alpha;
  final double baseAngle;
  final double spin;
}
