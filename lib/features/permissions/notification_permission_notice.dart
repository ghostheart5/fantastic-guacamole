import 'package:fantastic_guacamole/features/permissions/notification_permission_flow.dart';
import 'package:fantastic_guacamole/l10n/journey_copy.dart';
import 'package:fantastic_guacamole/state/providers/notification_permission_provider.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A small notice shown while a reminder switch is on but notifications are
/// off for the app. Its one action asks in context, or opens device settings
/// once the system has refused (it may no longer show its dialog).
class NotificationPermissionNotice extends ConsumerWidget {
  const NotificationPermissionNotice({
    super.key,
    this.margin = EdgeInsets.zero,
  });

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(notificationPermissionSupportedProvider)) {
      return const SizedBox.shrink();
    }
    final NotificationPermissionMemory memory = ref.watch(
      notificationPermissionProvider,
    );
    ref.watch(restoredSettingsRevisionProvider);
    return ValueListenableBuilder<bool?>(
      valueListenable: ref.watch(notificationPermissionListenableProvider),
      builder: (BuildContext context, bool? granted, _) {
        if (granted != false ||
            memory.noticeDismissed ||
            !ref
                .read(notificationPermissionProvider.notifier)
                .anyReminderSwitchOn()) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: margin,
          child: Card(
            key: const Key('notification-permission-notice'),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 8),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.notifications_off_outlined,
                    color: AppColors.memoryAmber,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          journeyText(
                            context,
                            'Reminders are on, but notifications are off for Axiomara.',
                            'Los recordatorios están activados, pero las notificaciones de Axiomara están desactivadas.',
                          ),
                        ),
                        TextButton(
                          onPressed: () => _turnOn(context, ref),
                          child: Text(
                            journeyText(
                              context,
                              'Turn on notifications',
                              'Activar notificaciones',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: journeyText(context, 'Dismiss', 'Descartar'),
                    onPressed: () => ref
                        .read(notificationPermissionProvider.notifier)
                        .dismissNotice(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _turnOn(BuildContext context, WidgetRef ref) async {
    if (ref.read(notificationPermissionProvider).refusal ==
        NotificationPermissionRefusal.denied) {
      await openNotificationSystemSettings(context, ref);
      return;
    }
    await ensureNotificationPermission(context, ref, userInitiated: true);
  }
}
