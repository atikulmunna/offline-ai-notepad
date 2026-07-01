import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';

/// A reusable iOS-style "liquid glass" panel: a translucent gradient fill with
/// a hairline border, optionally backed by a live [BackdropFilter] blur.
///
/// Colors come from the theme's [AppSurfaces] extension so the same widget
/// reads correctly in both the light and AMOLED themes. Set [blur] to `false`
/// for surfaces that are painted many times (e.g. list cards), where a live
/// backdrop blur would be too expensive — the translucent fill still gives the
/// glass look without sampling the layer beneath every frame.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.blur = true,
    this.strongBorder = false,
    this.padding,
    this.shadow = true,
  });

  final Widget child;
  final double borderRadius;
  final bool blur;

  /// Uses the brighter highlight color for the outline (for small interactive
  /// chrome like buttons).
  final bool strongBorder;
  final EdgeInsetsGeometry? padding;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final radius = BorderRadius.circular(borderRadius);

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [surfaces.glassFillTop, surfaces.glassFillBottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: radius,
        border: Border.all(
          color: strongBorder ? surfaces.glassHighlight : surfaces.glassBorder,
        ),
      ),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );

    if (blur) {
      content = BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: surfaces.blurSigma,
          sigmaY: surfaces.blurSigma,
        ),
        child: content,
      );
    }

    final clipped = ClipRRect(borderRadius: radius, child: content);

    if (!shadow) {
      return clipped;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: clipped,
    );
  }
}
