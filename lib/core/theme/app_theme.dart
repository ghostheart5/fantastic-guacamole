import 'package:flutter/material.dart';

@immutable
class AppTheme {
  const AppTheme._();

  static const _primary = Color(0xFF5B8DEF);
  static const _background = Color(0xFF0F172A);
  static const _surface = Color(0xFF1E293B);
  static const _text = Color(0xFFE2E8F0);
  static const _textMuted = Color(0xFF94A3B8);
  static const _border = Color(0xFF2D3748);
  static const _radius = 12.0;

  static const AppThemeTokens tokens = AppThemeTokens(
    colors: AppThemeColors(
      background: _background,
      surface: _surface,
      primary: _primary,
      text: _text,
      textMuted: _textMuted,
      border: _border,
    ),
    radius: AppThemeRadius(sm: _radius, md: _radius, lg: _radius),
    typography: AppThemeTypography(
      title: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      body: TextStyle(fontSize: 14),
      caption: TextStyle(fontSize: 12, color: _textMuted),
    ),
  );

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _background,
      colorScheme: const ColorScheme.dark(
        primary: _primary,
        surface: _surface,
        onSurface: _text,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(fontSize: 14, color: _text),
        bodySmall: TextStyle(fontSize: 12, color: _textMuted),
      ),
      cardTheme: CardThemeData(
        color: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  static ThemeData get data => dark();

  // Compatibility aliases for widget-based screen compositions.
  static const Color bg = _background;
  static const Color surface = _surface;
  static const Color accent = _primary;
  static const BorderRadius radius = BorderRadius.all(Radius.circular(_radius));
  static const List<BoxShadow> glow = <BoxShadow>[
    BoxShadow(color: Color(0x4D5B8DEF), blurRadius: 20, spreadRadius: 1),
  ];
}

@immutable
class AppThemeTokens {
  const AppThemeTokens({
    required this.colors,
    required this.radius,
    required this.typography,
  });

  final AppThemeColors colors;
  final AppThemeRadius radius;
  final AppThemeTypography typography;

  double spacing(num n) => n * 8;
}

@immutable
class AppThemeColors {
  const AppThemeColors({
    required this.background,
    required this.surface,
    required this.primary,
    required this.text,
    required this.textMuted,
    required this.border,
  });

  final Color background;
  final Color surface;
  final Color primary;
  final Color text;
  final Color textMuted;
  final Color border;
}

@immutable
class AppThemeRadius {
  const AppThemeRadius({required this.sm, required this.md, required this.lg});

  final double sm;
  final double md;
  final double lg;
}

@immutable
class AppThemeTypography {
  const AppThemeTypography({
    required this.title,
    required this.body,
    required this.caption,
  });

  final TextStyle title;
  final TextStyle body;
  final TextStyle caption;
}
