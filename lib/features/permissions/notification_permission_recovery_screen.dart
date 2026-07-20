import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/services/reflection_reminder_service.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NotificationPermissionRecoveryScreen extends ConsumerWidget {
  const NotificationPermissionRecoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ValueListenable<NotificationPermissionState> permissionStateListenable =
        ref.watch(notificationPermissionStateListenableProvider);
    return AnimatedSystemBackground(
      backgroundAssetPath: 'assets/backgrounds/settings_bg.jpg',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_ios_new),
                      color: AppColors.neonCyan,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Notification Recovery',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.neonCyan.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Text(
                    'ChronoSpark cannot schedule reminders until system notification permission is enabled. Use the actions below to recover and re-enable alerts.',
                    style: TextStyle(color: Colors.white70, height: 1.45),
                  ),
                ),
                const SizedBox(height: 20),
                ValueListenableBuilder<NotificationPermissionState>(
                  valueListenable: permissionStateListenable,
                  builder: (context, state, _) {
                    if (state == NotificationPermissionState.permanentlyDenied) {
                      return const Text(
                        'Permission is permanently denied. Open system settings to re-enable notifications.',
                        style: TextStyle(color: Colors.white70, height: 1.4),
                      );
                    }

                    return FilledButton.icon(
                      onPressed: () async {
                        await ref
                            .read(settingsUiActionsProvider)
                            .requestNotificationPermissionDetailed();
                      },
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('Request Permission Again'),
                    );
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(settingsUiActionsProvider)
                        .openSystemAppSettings();
                  },
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Open System App Settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
