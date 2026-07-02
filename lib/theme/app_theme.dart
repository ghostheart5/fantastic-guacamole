import 'package:fantastic_guacamole/theme/colors.dart';
import 'package:fantastic_guacamole/theme/radii.dart';
import 'package:fantastic_guacamole/theme/theme_extensions.dart';
import 'package:fantastic_guacamole/theme/typography.dart';
import 'package:flutter/material.dart';

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: 'Inter',
  fontFamilyFallback: const <String>['Roboto', 'Noto Sans', 'Arial'],
  scaffoldBackgroundColor: backgroundDark,
  canvasColor: backgroundDark,
  splashFactory: InkRipple.splashFactory,
  colorScheme: const ColorScheme.dark(
    primary: primaryNeon,
    secondary: neonViolet,
    tertiary: neonMagenta,
    surface: surfaceDark,
    onPrimary: backgroundDark,
    onSecondary: Colors.white,
    onSurface: Colors.white,
    error: Color(0xFFFF5C93),
  ),
  textTheme: neonTextTheme,
  extensions: const <ThemeExtension<dynamic>>[defaultNeonEffects],
  appBarTheme: AppBarTheme(
    backgroundColor: surfaceDark.withValues(alpha: 0.86),
    foregroundColor: hologramWhite,
    elevation: 0,
    centerTitle: true,
    shadowColor: neonCyan.withValues(alpha: 0.22),
    surfaceTintColor: Colors.transparent,
    titleTextStyle: neonTextTheme.headlineMedium?.copyWith(fontSize: 20),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: surfaceDark.withValues(alpha: 0.94),
    selectedItemColor: neonCyan,
    unselectedItemColor: hologramWhite.withValues(alpha: 0.7),
    selectedLabelStyle: neonTextTheme.labelLarge,
    unselectedLabelStyle: neonTextTheme.labelLarge?.copyWith(
      color: hologramWhite.withValues(alpha: 0.6),
      fontWeight: FontWeight.w600,
    ),
    showUnselectedLabels: true,
    elevation: 0,
    type: BottomNavigationBarType.fixed,
  ),
  buttonTheme: ButtonThemeData(
    shape: const RoundedRectangleBorder(borderRadius: buttonRadius),
    buttonColor: neonCyan,
    splashColor: neonMagenta.withValues(alpha: 0.18),
    textTheme: ButtonTextTheme.primary,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: surfaceElevated,
      foregroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: buttonRadius),
      side: BorderSide(color: hologramWhite.withValues(alpha: 0.3), width: 1.2),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      textStyle: neonTextTheme.labelLarge,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: surfaceDark.withValues(alpha: 0.82),
    hintStyle: neonTextTheme.bodyLarge?.copyWith(
      color: hologramWhite.withValues(alpha: 0.48),
    ),
    labelStyle: neonTextTheme.labelLarge,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    enabledBorder: OutlineInputBorder(
      borderRadius: inputRadius,
      borderSide: BorderSide(
        color: hologramWhite.withValues(alpha: 0.18),
        width: 1.2,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: inputRadius,
      borderSide: BorderSide(
        color: neonCyan.withValues(alpha: 0.9),
        width: 1.6,
      ),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: inputRadius,
      borderSide: BorderSide(color: Color(0xFFFF5C93), width: 1.2),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: inputRadius,
      borderSide: BorderSide(color: Color(0xFFFF5C93), width: 1.6),
    ),
    border: OutlineInputBorder(
      borderRadius: inputRadius,
      borderSide: BorderSide(
        color: hologramWhite.withValues(alpha: 0.18),
        width: 1.2,
      ),
    ),
  ),
  cardTheme: CardThemeData(
    color: surfaceDark.withValues(alpha: 0.88),
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: cardRadius,
      side: BorderSide(
        color: hologramWhite.withValues(alpha: 0.18),
        width: 1.1,
      ),
    ),
    shadowColor: neonViolet.withValues(alpha: 0.16),
  ),
  dividerColor: hologramWhite.withValues(alpha: 0.14),
  iconTheme: const IconThemeData(color: neonCyan),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: surfaceElevated,
    contentTextStyle: neonTextTheme.bodyLarge,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: cardRadius,
      side: BorderSide(color: hologramWhite.withValues(alpha: 0.16), width: 1),
    ),
  ),
  dialogTheme: const DialogThemeData(backgroundColor: surfaceElevated),
).copyWith(shadowColor: neonCyan.withValues(alpha: 0.18));
