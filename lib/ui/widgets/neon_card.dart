import 'package:fantastic_guacamole/core/constants/app_sizes.dart';
import 'package:fantastic_guacamole/theme/widgets/neon_card.dart' as themed;
import 'package:flutter/material.dart';

class NeonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool enableGlow;

  const NeonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSizes.md),
    this.enableGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return themed.NeonCard(
      padding: padding,
      enableGlow: enableGlow,
      child: child,
    );
  }
}
