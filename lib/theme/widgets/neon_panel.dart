import 'package:fantastic_guacamole/theme/colors.dart';
import 'package:fantastic_guacamole/theme/radii.dart';
import 'package:fantastic_guacamole/theme/shadows.dart';
import 'package:fantastic_guacamole/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

class NeonPanel extends StatelessWidget {
  const NeonPanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(24),
    this.header,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final NeonEffects effects = Theme.of(context).extension<NeonEffects>() ?? defaultNeonEffects;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: cosmicGradient,
        borderRadius: panelRadius,
        border: Border.all(
          color: hologramWhite.withValues(alpha: effects.hologramOpacity),
          width: effects.borderThickness,
        ),
        boxShadow: softAmbientGlow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (header case final Widget headerWidget) ...<Widget>[
            headerWidget,
            const SizedBox(height: 18),
          ],
          child,
        ],
      ),
    );
  }
}
