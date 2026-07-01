import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

ThemeData buildDarkTheme() {
  const ColorScheme scheme = ColorScheme.dark(
    primary: AppColors.neonCyan,
    secondary: AppColors.neonViolet,
    surface: AppColors.bgSecondary,
    surfaceContainer: AppColors.bgTertiary,
    onSurface: AppColors.textPrimary,
    outline: AppColors.panelBorder,
    error: AppColors.recallRed,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'FiraCode',
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bgPrimary,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgSecondary,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'InterBlack',
        fontSize: 24,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
        letterSpacing: 0.6,
      ),
      displayMedium: TextStyle(
        fontFamily: 'InterBlack',
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
        letterSpacing: 0.6,
      ),
      displaySmall: TextStyle(
        fontFamily: 'InterBlack',
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
        letterSpacing: 0.6,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'InterBlack',
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
        letterSpacing: 0.4,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'InterBlack',
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
        letterSpacing: 0.4,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'InterBlack',
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
        letterSpacing: 0.4,
      ),
      titleLarge: TextStyle(
        fontFamily: 'FiraCode',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: 0.2,
      ),
      titleMedium: TextStyle(
        fontFamily: 'InterBlack',
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
        letterSpacing: 0.2,
      ),
      titleSmall: TextStyle(
        fontFamily: 'FiraCode',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: 0.2,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'FiraCode',
        fontSize: 16,
        color: AppColors.textMuted,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'FiraCode',
        fontSize: 14,
        color: AppColors.textMuted,
      ),
      bodySmall: TextStyle(
        fontFamily: 'FiraCode',
        fontSize: 13,
        color: AppColors.textDim,
      ),
      labelLarge: TextStyle(
        fontFamily: 'InterBlack',
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
      ),
      labelMedium: TextStyle(
        fontFamily: 'FiraCode',
        fontSize: 12,
        color: AppColors.textMuted,
      ),
      labelSmall: TextStyle(
        fontFamily: 'FiraCode',
        fontSize: 12,
        color: AppColors.textDim,
      ),
    ),
    dividerColor: AppColors.panelBorder,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0x1AFFFFFF),
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
      labelStyle: TextStyle(fontFamily: 'FiraCode', color: AppColors.textPrimary),
      side: BorderSide(color: AppColors.panelBorder),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.bgSecondary,
      contentTextStyle: TextStyle(fontFamily: 'FiraCode', color: AppColors.textPrimary),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.pulseNeonBlue,
      linearTrackColor: Color(0x332A2E38),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: _SoftFadeSlideTransitionsBuilder(),
        TargetPlatform.iOS: _SoftFadeSlideTransitionsBuilder(),
        TargetPlatform.windows: _SoftFadeSlideTransitionsBuilder(),
        TargetPlatform.macOS: _SoftFadeSlideTransitionsBuilder(),
        TargetPlatform.linux: _SoftFadeSlideTransitionsBuilder(),
      },
    ),
  );
}

class _SoftFadeSlideTransitionsBuilder extends PageTransitionsBuilder {
  const _SoftFadeSlideTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final Animation<Offset> slide = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

    return FadeTransition(opacity: animation, child: SlideTransition(position: slide, child: child));
  }
}
