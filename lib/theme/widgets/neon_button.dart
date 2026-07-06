import 'package:fantastic_guacamole/theme/colors.dart';
import 'package:fantastic_guacamole/theme/radii.dart';
import 'package:fantastic_guacamole/theme/shadows.dart';
import 'package:fantastic_guacamole/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

class NeonButton extends StatelessWidget {
  const NeonButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.accentColor,
    this.icon,
    this.isEnabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? accentColor;
  final Widget? icon;
  final bool isEnabled;

  List<BoxShadow> _glowFor(Color color) {
    if (color == neonViolet) {
      return neonGlowViolet;
    }
    if (color == neonMagenta) {
      return neonGlowMagenta;
    }
    return neonGlowCyan;
  }

  @override
  Widget build(BuildContext context) {
    final NeonEffects effects = Theme.of(context).extension<NeonEffects>() ?? defaultNeonEffects;
    final Color glowColor = accentColor ?? neonCyan;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: buttonRadius,
        boxShadow: isEnabled ? _glowFor(glowColor) : const <BoxShadow>[],
      ),
      child: ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: surfaceElevated,
          foregroundColor: Colors.white,
          disabledBackgroundColor: surfaceDark,
          disabledForegroundColor: hologramWhite.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: buttonRadius,
            side: BorderSide(
              color: glowColor.withValues(alpha: effects.hologramOpacity + 0.08),
              width: effects.borderThickness,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (icon case final Widget iconWidget) ...<Widget>[
              iconWidget,
              const SizedBox(width: 10),
            ],
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: glowColor, letterSpacing: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
