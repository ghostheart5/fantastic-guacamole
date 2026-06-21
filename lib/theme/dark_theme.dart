import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

ThemeData buildDarkTheme() {
  const ColorScheme scheme = ColorScheme.dark(
    primary: AppColors.pulseNeonBlue,
    secondary: AppColors.recallRed,
    surface: AppColors.bgSecondary,
    error: AppColors.recallRed,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bgPrimary,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgSecondary,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      titleMedium: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      bodyMedium: TextStyle(color: AppColors.textMuted),
    ),
    dividerColor: AppColors.panelBorder,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.panelGlass,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.panelBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.panelBorder),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: AppColors.panelGlass,
      selectedColor: AppColors.neonCyan,
      labelStyle: TextStyle(color: AppColors.textPrimary),
      side: BorderSide(color: AppColors.panelBorder),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF1A1014),
      contentTextStyle: TextStyle(color: AppColors.textPrimary),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.pulseNeonBlue,
      linearTrackColor: Color(0x332A2E38),
    ),
  );
}
