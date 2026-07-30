import 'package:fantastic_guacamole/theme/colors.dart';
import 'package:flutter/material.dart';

class NeonDivider extends StatelessWidget {
  const NeonDivider({super.key, this.height = 1.5, this.margin});

  final double height;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        gradient: neonPulseGradient,
        borderRadius: BorderRadius.circular(height),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x2600E5FF),
            blurRadius: 12,
            spreadRadius: 0,
            offset: Offset(0, 0),
          ),
        ],
      ),
    );
  }
}
