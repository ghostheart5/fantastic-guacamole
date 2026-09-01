import 'dart:ui';

import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_sizes.dart';
import 'package:flutter/material.dart';

class TemporalGlassSurface extends StatelessWidget {
  const TemporalGlassSurface({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(18),
    this.accent = AppColors.neonCyan,
    this.opacity = 0.88,
    this.blur = 16,
    this.width,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color accent;
  final double opacity;
  final double blur;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final double surfaceOpacity = opacity.clamp(0.0, 1.0);
    final double lowerOpacity = (surfaceOpacity - 0.06).clamp(0.0, 1.0);
    return SizedBox(
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  AppColors.bgSecondary.withValues(alpha: surfaceOpacity),
                  AppColors.background.withValues(alpha: lowerOpacity),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accent.withValues(alpha: 0.32)),
              boxShadow: <BoxShadow>[
                const BoxShadow(
                  color: Color(0x42000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
                BoxShadow(
                  color: accent.withValues(alpha: 0.08),
                  blurRadius: 22,
                ),
              ],
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class TemporalScreenHeader extends StatelessWidget {
  const TemporalScreenHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.eyebrow,
    this.onBack,
    this.backTooltip = 'Back',
    this.trailing,
    this.accent = AppColors.neonCyan,
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final VoidCallback? onBack;
  final String backTooltip;
  final Widget? trailing;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (onBack != null) ...<Widget>[
          Semantics(
            label: backTooltip,
            button: true,
            excludeSemantics: true,
            child: IconButton(
              tooltip: backTooltip,
              onPressed: onBack,
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              icon: const Icon(Icons.arrow_back_rounded),
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (eyebrow case final String value) ...<Widget>[
                Text(
                  value.toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              if (subtitle case final String value) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing case final Widget value) ...<Widget>[
          const SizedBox(width: 12),
          SizedBox(width: 48, height: 48, child: Center(child: value)),
        ],
      ],
    );
  }
}

class TemporalDivider extends StatelessWidget {
  const TemporalDivider({super.key, this.color = AppColors.neonCyan});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Divider(color: color.withValues(alpha: 0.28))),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: <BoxShadow>[
              BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8),
            ],
          ),
        ),
        Expanded(child: Divider(color: color.withValues(alpha: 0.28))),
      ],
    );
  }
}

class TemporalActionButton extends StatelessWidget {
  const TemporalActionButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.accent = AppColors.neonCyan,
    this.filled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color accent;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final ButtonStyle style = filled
        ? FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: AppColors.background,
            disabledBackgroundColor: accent.withValues(alpha: 0.18),
            minimumSize: const Size.fromHeight(AppSizes.touchTarget),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: accent,
            minimumSize: const Size.fromHeight(AppSizes.touchTarget),
            side: BorderSide(color: accent.withValues(alpha: 0.72)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          );
    final Widget labelWidget = Text(
      label,
      maxLines: 2,
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0),
    );
    return filled
        ? FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon ?? Icons.arrow_forward_rounded),
            label: labelWidget,
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon ?? Icons.arrow_forward_rounded),
            label: labelWidget,
          );
  }
}

class TemporalStatusRow extends StatelessWidget {
  const TemporalStatusRow({
    required this.icon,
    required this.text,
    super.key,
    this.color = AppColors.neonCyan,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
