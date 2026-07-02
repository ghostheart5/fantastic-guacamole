import 'package:flutter/material.dart';

class UI {
  const UI._();

  static const double padding = 16;
  static const double radius = 16;

  static const TextStyle heading = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const TextStyle body = TextStyle(fontSize: 14, color: Colors.white70);

  static const Duration fadeIn = Duration(milliseconds: 360);

  static List<BoxShadow> glow(Color color) {
    return <BoxShadow>[
      BoxShadow(
        color: color.withValues(alpha: 0.22),
        blurRadius: 18,
        spreadRadius: 1,
      ),
    ];
  }
}
