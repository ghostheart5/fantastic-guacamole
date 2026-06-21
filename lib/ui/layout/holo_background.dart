import 'package:flutter/material.dart';

import '../../theme/decorations.dart';

class HoloBackground extends StatelessWidget {
  final Widget child;
  const HoloBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        gradient: AppDecorations.appBackground,
      ),
      child: child,
    );
  }
}
