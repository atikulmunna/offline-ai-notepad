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
    this.fillColor,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final double borderRadius;
  final bool blur;

  /// Uses the brighter highlight color for the outline (for small interactive
  /// chrome like buttons).
  final bool strongBorder;
  final EdgeInsetsGeometry? padding;
  final bool shadow;

  /// When set, paints a solid translucent fill instead of the default glass
  /// gradient (e.g. cards passing `AppSurfaces.cardFill`).
  final Color? fillColor;
  final Color? borderColor;

  /// When set, the whole surface becomes tappable with a matching ripple.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).extension<AppSurfaces>()!;
    final radius = BorderRadius.circular(borderRadius);
    final border = borderColor ??
        (strongBorder ? surfaces.glassHighlight : surfaces.glassBorder);

    final padded =
        padding == null ? child : Padding(padding: padding!, child: child);

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: fillColor,
        gradient: fillColor != null
            ? null
            : LinearGradient(
                colors: [surfaces.glassFillTop, surfaces.glassFillBottom],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: radius,
        border: Border.all(color: border),
      ),
      child: onTap == null
          ? padded
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: radius,
                onTap: onTap,
                child: padded,
              ),
            ),
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
