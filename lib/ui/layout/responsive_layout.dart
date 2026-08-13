import 'package:flutter/material.dart';

/// Shared viewport rules for phone portrait, compact landscape, and tablets.
abstract final class AppViewport {
  static const double compactWidth = 600;
  static const double tabletWidth = 840;
  static const double desktopWidth = 1200;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compactWidth;

  static bool isCompactHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 480;

  static EdgeInsets pagePadding(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final double horizontal = width < compactWidth
        ? 16
        : width < tabletWidth
        ? 24
        : 32;
    final double vertical = isCompactHeight(context) ? 12 : 20;
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }

  static double contentMaxWidth(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    if (width >= desktopWidth) return 1120;
    if (width >= tabletWidth) return 920;
    return double.infinity;
  }
}

/// Centers a readable content column on tablets and wide displays without
/// constraining standard phone layouts.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    required this.child,
    this.maxWidth,
    this.alignment = Alignment.topCenter,
    super.key,
  });

  final Widget child;
  final double? maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? AppViewport.contentMaxWidth(context),
        ),
        child: child,
      ),
    );
  }
}
