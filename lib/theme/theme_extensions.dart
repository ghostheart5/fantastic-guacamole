import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
class NeonEffects extends ThemeExtension<NeonEffects> {
  const NeonEffects({
    required this.glowIntensity,
    required this.hologramOpacity,
    required this.borderThickness,
  });

  final double glowIntensity;
  final double hologramOpacity;
  final double borderThickness;

  @override
  NeonEffects copyWith({
    double? glowIntensity,
    double? hologramOpacity,
    double? borderThickness,
  }) {
    return NeonEffects(
      glowIntensity: glowIntensity ?? this.glowIntensity,
      hologramOpacity: hologramOpacity ?? this.hologramOpacity,
      borderThickness: borderThickness ?? this.borderThickness,
    );
  }

  @override
  NeonEffects lerp(ThemeExtension<NeonEffects>? other, double t) {
    if (other is! NeonEffects) {
      return this;
    }

    return NeonEffects(
      glowIntensity:
          lerpDouble(glowIntensity, other.glowIntensity, t) ?? glowIntensity,
      hologramOpacity:
          lerpDouble(hologramOpacity, other.hologramOpacity, t) ??
          hologramOpacity,
      borderThickness:
          lerpDouble(borderThickness, other.borderThickness, t) ??
          borderThickness,
    );
  }
}

const NeonEffects defaultNeonEffects = NeonEffects(
  glowIntensity: 1,
  hologramOpacity: 0.22,
  borderThickness: 1.4,
);
