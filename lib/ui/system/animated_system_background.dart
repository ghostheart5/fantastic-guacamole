import 'package:flutter/material.dart';

class AnimatedSystemBackground extends StatelessWidget {
  const AnimatedSystemBackground({super.key, required this.backgroundAsset});

  final String backgroundAsset;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      backgroundAsset,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
          const ColoredBox(color: Color(0xFF0C0812)),
    );
  }
}
