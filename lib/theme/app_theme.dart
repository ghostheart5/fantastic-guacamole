import 'package:flutter/material.dart';

import 'dark_theme.dart';
import 'neon_recall_theme.dart';

class AppTheme {
  static ThemeData dark() {
    return buildDarkTheme();
  }

  static ThemeData neonRecall() => buildNeonRecallTheme();
}
