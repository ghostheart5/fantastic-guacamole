import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          colors: active
              ? <Color>[AppColors.neonCyan, AppColors.neonViolet]
              : <Color>[Colors.white24, Colors.white10],
        ),
      ),
      child: Text(
        active ? 'PREMIUM ACTIVE' : 'FREE PLAN',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: Colors.white,
        ),
      ),
    );
  }
}