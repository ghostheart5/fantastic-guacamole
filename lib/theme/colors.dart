import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

const Color primaryNeon = Color(0xFF00E5FF);
const Color neonCyan = Color(0xFF00E5FF);

/// Forwards to [AppColors.neonViolet] so the app has one violet accent.
///
/// This file previously declared `0xFF9A4DFF` while `AppColors` declared
/// `0xFF9B8AFB`, so the accent rendered differently depending on which colour
/// file a widget imported.
const Color neonViolet = AppColors.neonViolet;

/// Legacy alias retained for source compatibility.
///
/// Temporal Glass uses cyan, violet, and amber. Keeping the old name mapped
/// to amber prevents legacy widgets from reintroducing the retired magenta
/// accent.
const Color neonMagenta = AppColors.memoryAmber;
const Color backgroundDark = Color(0xFF050510);
const Color backgroundDeep = Color(0xFF0A0F1F);
const Color hologramWhite = Color(0xDEFFFFFF);
const Color hologramBorder = Color(0x33FFFFFF);
const Color surfaceDark = Color(0xFF0D1324);
const Color surfaceElevated = Color(0xFF12192D);

const LinearGradient cosmicGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: <Color>[backgroundDark, backgroundDeep],
);

const LinearGradient neonPulseGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: <Color>[neonCyan, neonViolet, neonMagenta],
);

const LinearGradient glassPanelGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: <Color>[Color(0xCC12192D), Color(0xB30D1324)],
);
