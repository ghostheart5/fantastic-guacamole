import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
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
    return TemporalGlassSurface(
      accent: AppColors.memoryAmber,
      opacity: 0.92,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox.square(
                dimension: 48,
                child: Icon(
                  Icons.settings_outlined,
                  color: AppColors.memoryAmber,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'SYSTEM ACCESS NEEDED',
                      style: TextStyle(
                        color: AppColors.memoryAmber,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.45,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 14),
          TemporalActionButton(
            label: 'Open Settings',
            icon: Icons.settings_outlined,
            accent: AppColors.memoryAmber,
            onPressed: () async => onOpenSystemSettings(),
          ),
          if (onDismiss != null) ...<Widget>[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onDismiss,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppColors.neonViolet.withValues(alpha: 0.45),
                  ),
                  foregroundColor: AppColors.neonViolet,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Dismiss'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
