import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'core/state/app_state.dart';
import 'features/system_shell/main_shell.dart';

class ChronoSparkSystemApp extends StatelessWidget {
  const ChronoSparkSystemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>(
      create: (_) => AppState(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ChronoSpark',
        theme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: GoogleFonts.orbitron().fontFamily,
          scaffoldBackgroundColor: Colors.transparent,
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFC2A7FF),
            secondary: Color(0xFFFF8FB6),
            surface: Color(0xFF130B19),
          ),
          useMaterial3: true,
          textTheme: TextTheme(
            // ── Orbitron display: largest branding moments ─────────────────
            displayLarge: GoogleFonts.orbitron(
              fontSize: 24,
              color: const Color(0xFFECE8F9),
              letterSpacing: 1.2,
            ),
            displayMedium: GoogleFonts.orbitron(
              fontSize: 22,
              color: const Color(0xFFECE8F9),
              letterSpacing: 1.2,
            ),
            displaySmall: GoogleFonts.orbitron(
              fontSize: 20,
              color: const Color(0xFFECE8F9),
              letterSpacing: 1.2,
            ),
            // ── Orbitron headlines: section headers ────────────────────────
            headlineLarge: GoogleFonts.orbitron(
              fontSize: 22,
              color: const Color(0xFFECE8F9),
              letterSpacing: 1.2,
            ),
            headlineMedium: GoogleFonts.orbitron(
              fontSize: 20,
              color: const Color(0xFFECE8F9),
              letterSpacing: 1.2,
            ),
            headlineSmall: GoogleFonts.orbitron(
              fontSize: 18,
              color: const Color(0xFFECE8F9),
              letterSpacing: 1.2,
            ),
            // ── Orbitron titles: card headers and panel labels ─────────────
            titleLarge: GoogleFonts.orbitron(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFECE8F9),
              letterSpacing: 1.2,
            ),
            titleMedium: GoogleFonts.orbitron(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFECE8F9),
              letterSpacing: 1.2,
            ),
            titleSmall: GoogleFonts.orbitron(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFECE8F9),
              letterSpacing: 1.2,
            ),
            // ── Poppins body: readable content copy ───────────────────────
            bodyLarge: GoogleFonts.poppins(fontSize: 16, color: const Color(0xFFD8D0E6)),
            bodyMedium: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFFD8D0E6)),
            bodySmall: GoogleFonts.poppins(fontSize: 13, color: Color(0xFF9E9E9E)),
            // ── Inter labels: chips, buttons, muted metadata ───────────────
            labelLarge: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFECE8F9),
            ),
            labelMedium: GoogleFonts.inter(fontSize: 12, color: Color(0xFF9E9E9E)),
            labelSmall: GoogleFonts.inter(fontSize: 12, color: Color(0xFF9E9E9E)),
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
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0x1AFFFFFF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0x33FFFFFF)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0x33FFFFFF)),
            ),
          ),
        ),
        builder: (BuildContext context, Widget? child) {
          final double textScale = context.watch<AppState>().textScale;
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          );
        },
        home: const MainShell(),
      ),
    );
  }
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

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(position: slide, child: child),
    );
  }
}
