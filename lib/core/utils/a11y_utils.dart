import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Accessibility utilities and helpers
class A11yUtils {
  /// Compute contrast ratio between two colors (for WCAG compliance checking)
  static double computeContrastRatio(Color color1, Color color2) {
    final double lum1 = _getRelativeLuminance(color1);
    final double lum2 = _getRelativeLuminance(color2);

    final double lighter = (lum1 > lum2) ? lum1 : lum2;
    final double darker = (lum1 > lum2) ? lum2 : lum1;

    return (lighter + 0.05) / (darker + 0.05);
  }

  static double _getRelativeLuminance(Color color) {
    final double r = _linearize(color.r);
    final double g = _linearize(color.g);
    final double b = _linearize(color.b);

    return (0.2126 * r) + (0.7152 * g) + (0.0722 * b);
  }

  static double _linearize(double value) {
    if (value <= 0.03928) {
      return value / 12.92;
    }
    return math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  /// Check if contrast ratio meets WCAG AA standard (4.5:1 for normal text)
  static bool meetsWCAGAA(Color foreground, Color background) {
    return computeContrastRatio(foreground, background) >= 4.5;
  }

  /// Check if contrast ratio meets WCAG AAA standard (7:1 for normal text)
  static bool meetsWCAGAAA(Color foreground, Color background) {
    return computeContrastRatio(foreground, background) >= 7.0;
  }

  /// Get responsive text scale factor based on MediaQuery
  static double getTextScaleFactor(BuildContext context) {
    return MediaQuery.textScalerOf(context).scale(1.0);
  }

  /// Check if high contrast mode is enabled
  static bool isHighContrastEnabled(BuildContext context) {
    return MediaQuery.highContrastOf(context);
  }

  /// Check if bold text is enabled (accessibility setting)
  static bool isBoldTextEnabled(BuildContext context) {
    return MediaQuery.boldTextOf(context);
  }

  /// Get minimum touch target size (48dp recommended by Material Design)
  static const double minTouchTargetSize = 48.0;

  /// Minimum font size for accessibility
  static const double minFontSize = 12.0;
}

/// Accessibility-aware button widget
class A11yButton extends StatelessWidget {
  const A11yButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tooltip,
    this.enabled = true,
    this.filled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? tooltip;
  final bool enabled;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final button = filled
        ? FilledButton(
            onPressed: enabled ? onPressed : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon),
                  const SizedBox(width: 8),
                ],
                Semantics(
                  button: true,
                  enabled: enabled,
                  onTap: onPressed,
                  label: label,
                  child: Text(label),
                ),
              ],
            ),
          )
        : OutlinedButton(
            onPressed: enabled ? onPressed : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon),
                  const SizedBox(width: 8),
                ],
                Semantics(
                  button: true,
                  enabled: enabled,
                  onTap: onPressed,
                  label: label,
                  child: Text(label),
                ),
              ],
            ),
          );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}

/// Accessibility-aware text field
class A11yTextField extends StatelessWidget {
  const A11yTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.errorText,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      enabled: enabled,
      label: label,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: errorText,
          errorText: errorText,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }
}

/// Accessibility-aware icon button
class A11yIconButton extends StatelessWidget {
  const A11yIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.label,
    this.tooltip,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String label;
  final String? tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      onTap: onPressed,
      label: label,
      child: Tooltip(
        message: tooltip ?? label,
        child: SizedBox(
          width: A11yUtils.minTouchTargetSize,
          height: A11yUtils.minTouchTargetSize,
          child: IconButton(
            icon: Icon(icon),
            onPressed: enabled ? onPressed : null,
            tooltip: tooltip ?? label,
          ),
        ),
      ),
    );
  }
}

/// Accessibility wrapper for any widget
class A11yWidget extends StatelessWidget {
  const A11yWidget({
    super.key,
    required this.child,
    required this.label,
    this.enabled = true,
    this.button = false,
    this.onTap,
  });

  final Widget child;
  final String label;
  final bool enabled;
  final bool button;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: button,
      enabled: enabled,
      label: label,
      onTap: onTap,
      child: child,
    );
  }
}
