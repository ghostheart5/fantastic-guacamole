import 'package:flutter/material.dart';

class AppColors {
  // ChronoSpark base palette (deep navy / midnight tones)
  static const Color bgPrimary = Color(0xFF0B0F1A);
  static const Color bgSecondary = Color(0xFF111827);
  static const Color bgTertiary = Color(0xFF172033);

  // Glassmorphism panels (semi-transparent with blur effect)
  static const Color panelGlass = Color(0x1A141D30); // 10% glass panel
  static const Color panelGlassAlt = Color(0x2420334D); // 14% elevated panel
  static const Color panelBorder = Color(0x4000D4FF); // 25% cyan border

  // Neon accent colors
  static const Color neonCyan = Color(0xFF00D4FF);
  static const Color neonViolet = Color(0xFF7A5CFF);
  static const Color neonCyanAlt = Color(0xFF63E6FF);
  static const Color neonVioletAlt = Color(0xFFA996FF);

  // Legacy compatibility
  static const Color recallRed = Color(0xFFFF2A3D);
  static const Color neuroSteel = Color(0xFFA8B1C2);
  static const Color pulseNeonBlue = neonCyan;
  static const Color memoryAmber = Color(0xFFFFB85C);
  static const Color neonBlue = neonCyan;
  static const Color neonGreen = Color(0xFF7CF5D6);
  static const Color neonAmber = memoryAmber;

  // Text colors for premium feel
  static const Color textPrimary = Color(0xFFEAF3FF);
  static const Color textMuted = Color(0xFF9CB0CC);
  static const Color textDim = Color(0xFF6E82A3);

  // Glow colors for effects
  static const Color glowCyan = Color(0x5900D4FF);
  static const Color glowViolet = Color(0x4D7A5CFF);
}
