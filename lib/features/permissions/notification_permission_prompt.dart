import 'package:fantastic_guacamole/features/permissions/permission_denied_recovery.dart';
import 'package:fantastic_guacamole/features/permissions/permission_explainer.dart';
import 'package:fantastic_guacamole/features/permissions/permission_rationale_sheet.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

class NotificationPermissionPrompt extends StatelessWidget {
  const NotificationPermissionPrompt({
    super.key,
    required this.permissionGranted,
    required this.onRequestPermission,
    required this.onOpenSystemSettings,
    this.title = 'Notifications',
  });

  final bool? permissionGranted;
  final Future<bool> Function() onRequestPermission;
  final Future<void> Function() onOpenSystemSettings;
  final String title;

  @override
  Widget build(BuildContext context) {
    final bool granted = permissionGranted == true;
    final bool denied = permissionGranted == false;

    if (granted) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.neonCyan.withValues(alpha: 0.06),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.25)),
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
          const Text(
            'Enable notifications to receive scheduled focus and reflection reminders.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () async {
              await showPermissionRationaleSheet<void>(
                context: context,
                explainer: PermissionExplainers.notification,
                onPrimary: () async {
                  await onRequestPermission();
                },
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.neonCyan,
              foregroundColor: Colors.black,
            ),
            child: const Text('Enable Notifications'),
          ),
          if (denied) ...<Widget>[
            const SizedBox(height: 10),
            PermissionDeniedRecovery(
              title: 'Permission Denied',
              message:
                  'Notifications are disabled at system level. Open settings to re-enable alerts.',
              onOpenSystemSettings: onOpenSystemSettings,
            ),
          ],
        ],
      ),
    );
  }
}
