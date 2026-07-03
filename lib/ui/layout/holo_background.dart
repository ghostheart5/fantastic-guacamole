import 'package:fantastic_guacamole/core/theme/decorations.dart';
import 'package:flutter/material.dart';

class HoloBackground extends StatelessWidget {
  final Widget child;
  const HoloBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        image: DecorationImage(
          image: AssetImage('assets/backgrounds/home_bg.jpg'),
          fit: BoxFit.cover,
        ),
        gradient: AppDecorations.appBackground,
      ),
      child: child,
    );
  }
}
