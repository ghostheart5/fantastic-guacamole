import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/core/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';

class PlanHeader extends StatelessWidget {
  const PlanHeader({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SmartPressable(
          onTap: onBack,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.neonCyan.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.neonCyan.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: AppColors.neonCyan,
              size: 16,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Container(
          width: 3,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.neonViolet,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonViolet.withValues(alpha: 0.8),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppColors.neonViolet, AppColors.neonCyan],
                  ).createShader(bounds),
                  child: const Text(
                    'DAY PLAN',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'TEMPORAL SCHEDULE',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2,
                    color: Colors.white38,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
