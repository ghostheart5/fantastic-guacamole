import 'package:flutter/material.dart';
import 'dart:ui';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

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
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.panelRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.panelGlass,
            borderRadius: BorderRadius.circular(AppSizes.panelRadius),
            border: Border.all(color: AppColors.panelBorder, width: 0.5),
            boxShadow: enableGlow
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.glowCyan.withValues(alpha: 0.3),
                      blurRadius: 24,
                      spreadRadius: -2,
                    ),
                    BoxShadow(
                      color: AppColors.glowViolet.withValues(alpha: 0.15),
                      blurRadius: 16,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
