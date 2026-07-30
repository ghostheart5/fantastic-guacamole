import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

class PermissionDeniedRecovery extends StatelessWidget {
  const PermissionDeniedRecovery({
    super.key,
    required this.title,
    required this.message,
    required this.onOpenSystemSettings,
    this.onDismiss,
  });

  final String title;
  final String message;
  final Future<void> Function() onOpenSystemSettings;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.recallRed.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.recallRed.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: () async => onOpenSystemSettings(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.recallRed,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.settings, size: 16),
                label: const Text('Open Settings'),
              ),
              OutlinedButton(
                onPressed: onDismiss,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppColors.neonViolet.withValues(alpha: 0.45),
                  ),
                  foregroundColor: AppColors.neonViolet,
                ),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
