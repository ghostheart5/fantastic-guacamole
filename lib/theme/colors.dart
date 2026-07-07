import 'package:flutter/material.dart';

const Color primaryNeon = Color(0xFF00E5FF);
const Color neonCyan = Color(0xFF00E5FF);
const Color neonViolet = Color(0xFF9A4DFF);
const Color neonMagenta = Color(0xFFFF2EC4);
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
