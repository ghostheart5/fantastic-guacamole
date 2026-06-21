import 'package:flutter/material.dart';

class AppColors {
  // Deep black background for OS aesthetic
  static const Color bgPrimary = Color(0xFF000000);
  static const Color bgSecondary = Color(0xFF0A0E27);
  static const Color bgTertiary = Color(0xFF1a1f3a);

  // Glassmorphism panels (semi-transparent with blur effect)
  static const Color panelGlass = Color(0x0D1A2A3D); // 5% opacity
  static const Color panelGlassAlt = Color(0x14FFFFFF); // 8% white overlay
  static const Color panelBorder = Color(0x2600F0FF); // 15% cyan

  // Neon accent colors
  static const Color neonCyan = Color(0xFF00F0FF);
  static const Color neonViolet = Color(0xFFA78BFA);
  static const Color neonCyanAlt = Color(0xFF3DF2FF);
  static const Color neonVioletAlt = Color(0xFFBB86FC);

  // Legacy compatibility
  static const Color recallRed = Color(0xFFFF2A3D);
  static const Color neuroSteel = Color(0xFFA8B1C2);
  static const Color pulseNeonBlue = neonCyan;
  static const Color memoryAmber = Color(0xFFFFB85C);
  static const Color neonBlue = neonCyan;
  static const Color neonGreen = Color(0xFF7CF5D6);
  static const Color neonAmber = memoryAmber;

  // Text colors for premium feel
  static const Color textPrimary = Color(0xFFF5F7FF);
  static const Color textMuted = Color(0xFF8A92A8);
  static const Color textDim = Color(0xFF5A6278);

  // Glow colors for effects
  static const Color glowCyan = Color(0x4400F0FF);
  static const Color glowViolet = Color(0x44A78BFA);
}
