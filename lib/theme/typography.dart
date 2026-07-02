import 'package:fantastic_guacamole/theme/colors.dart';
import 'package:flutter/material.dart';

final TextTheme _baseNeonTextTheme = ThemeData.dark().textTheme.apply(
  fontFamily: 'Inter',
);

final TextTheme neonTextTheme = _baseNeonTextTheme.copyWith(
  headlineLarge: _baseNeonTextTheme.headlineLarge?.copyWith(
    color: neonCyan,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.4,
  ),
  headlineMedium: _baseNeonTextTheme.headlineMedium?.copyWith(
    color: neonViolet,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.3,
  ),
  bodyLarge: _baseNeonTextTheme.bodyLarge?.copyWith(
    color: hologramWhite,
    fontWeight: FontWeight.w500,
    height: 1.5,
  ),
  labelLarge: _baseNeonTextTheme.labelLarge?.copyWith(
    color: neonMagenta,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  ),
);
