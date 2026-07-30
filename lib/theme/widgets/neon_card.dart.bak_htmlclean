import 'package:fantastic_guacamole/theme/colors.dart';
import 'package:fantastic_guacamole/theme/radii.dart';
import 'package:fantastic_guacamole/theme/shadows.dart';
import 'package:fantastic_guacamole/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

class NeonCard extends StatelessWidget {
  const NeonCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.enableGlow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool enableGlow;

  @override
  Widget build(BuildContext context) {
    final NeonEffects effects =
        Theme.of(context).extension<NeonEffects>() ?? defaultNeonEffects;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: glassPanelGradient,
        borderRadius: cardRadius,
        border: Border.all(
          color: hologramWhite.withValues(alpha: effects.hologramOpacity),
          width: effects.borderThickness,
        ),
        boxShadow: enableGlow ? softAmbientGlow : const <BoxShadow>[],
      ),
      child: child,
    );
  }
}
