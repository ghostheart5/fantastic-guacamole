import 'dart:ui';

import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.isActive = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      offset: isActive ? const Offset(0, -0.01) : Offset.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  AppColors.bgSecondary.withValues(alpha: 0.93),
                  AppColors.background.withValues(alpha: 0.86),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive
                    ? AppColors.neonCyan.withValues(alpha: 0.52)
                    : AppColors.panelBorder.withValues(alpha: 0.5),
              ),
              boxShadow: <BoxShadow>[
                const BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
                if (isActive)
                  BoxShadow(
                    color: AppColors.neonCyan.withValues(alpha: 0.12),
                    blurRadius: 18,
                  ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
