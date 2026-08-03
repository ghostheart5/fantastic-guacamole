import 'package:fantastic_guacamole/theme/colors.dart';
import 'package:flutter/material.dart';

final TextTheme _baseNeonTextTheme = ThemeData.dark().textTheme.apply(
  fontFamily: 'Inter',
);

final TextTheme neonTextTheme = _baseNeonTextTheme.copyWith(
  headlineLarge: _baseNeonTextTheme.headlineLarge?.copyWith(
    color: neonCyan,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.4,
    height: 1.15,
  ),
  headlineMedium: _baseNeonTextTheme.headlineMedium?.copyWith(
    color: neonViolet,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.3,
    height: 1.2,
  ),
  titleLarge: _baseNeonTextTheme.titleLarge?.copyWith(
    color: hologramWhite,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.2,
  ),
  titleMedium: _baseNeonTextTheme.titleMedium?.copyWith(
    color: hologramWhite,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.25,
  ),
  bodyLarge: _baseNeonTextTheme.bodyLarge?.copyWith(
    color: hologramWhite,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.55,
  ),
  bodyMedium: _baseNeonTextTheme.bodyMedium?.copyWith(
    color: hologramWhite.withValues(alpha: 0.9),
    fontSize: 13.5,
    height: 1.45,
  ),
  labelLarge: _baseNeonTextTheme.labelLarge?.copyWith(
    color: neonMagenta,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  ),
  labelMedium: _baseNeonTextTheme.labelMedium?.copyWith(
    color: hologramWhite.withValues(alpha: 0.85),
    fontSize: 12.5,
    height: 1.35,
  ),
);
