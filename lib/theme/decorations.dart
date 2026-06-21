import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

class AppDecorations {
  // Deep black OS background
  static const LinearGradient appBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[AppColors.bgPrimary, AppColors.bgSecondary],
  );

  // Alternative gradient for secondary surfaces
  static const LinearGradient neonRecallBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[AppColors.bgPrimary, AppColors.bgTertiary],
  );

  // Glassmorphic glow effect
  static const LinearGradient glassGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[AppColors.glowCyan, AppColors.glowViolet],
  );
}
