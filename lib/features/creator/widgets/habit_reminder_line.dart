import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/features/permissions/notification_permission_flow.dart';
import 'package:fantastic_guacamole/features/settings/ui/reminder_health.dart';
import 'package:fantastic_guacamole/l10n/journey_copy.dart';
import 'package:fantastic_guacamole/state/providers/notification_permission_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';

/// Why a saved habit reminder cannot arrive right now.
enum HabitReminderBlock { notificationsOff, remindersOff, habitRemindersOff }

/// The reason a habit reminder cannot be delivered, or null when it can (or
/// when nothing says otherwise yet). Reuses [reminderHealth] for the main
/// switch and permission, and adds the habit reminders switch.
HabitReminderBlock? habitReminderBlock({
  required bool remindersOn,
  required bool habitRemindersOn,
  required bool deviceSupported,
  required bool? permissionGranted,
}) {
  final ReminderHealth health = reminderHealth(
    remindersOn: remindersOn,
    deviceSupported: deviceSupported,
    permissionGranted: permissionGranted,
    lastResults: const <NotificationScheduleResult?>[],
  );
  return switch (health) {
    ReminderHealth.remindersOff => HabitReminderBlock.remindersOff,
    ReminderHealth.permissionOff => HabitReminderBlock.notificationsOff,
    _ when !habitRemindersOn => HabitReminderBlock.habitRemindersOff,
    _ => null,
  };
}

/// The reminder line on a habit card. When the reminder cannot be delivered
/// it is drawn inactive, says why in a few words, and offers one action; it
/// returns to normal by itself when that is fixed.
class HabitReminderLine extends ConsumerWidget {
  const HabitReminderLine({
    super.key,
    required this.habitId,
    required this.label,
  });

  final String habitId;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool deviceSupported = ref.watch(
      notificationPermissionSupportedProvider,
    );
    final ValueListenable<bool?> permission = ref.watch(
      notificationPermissionListenableProvider,
    );
    final ReminderOrchestratorService reminders = ref.watch(
      reminderOrchestratorServiceProvider,
    );
    ref.watch(restoredSettingsRevisionProvider);
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        permission,
        reminders.lastReminderResult,
        reminders.lastHabitReminderResult,
      ]),
      builder: (BuildContext context, _) {
        final ReminderOrchestratorPrefs prefs = ref
            .read(settingsUiActionsProvider)
            .loadAdvancedReminderPrefs();
        final HabitReminderBlock? block = habitReminderBlock(
          remindersOn: prefs.remindersEnabled,
          habitRemindersOn: prefs.habitRemindersEnabled,
          deviceSupported: deviceSupported,
          permissionGranted: permission.value,
        );
        final Text line = Text(
          label,
          key: ValueKey<String>('rhythm-reminder-label-$habitId'),
          style: block == null
              ? null
              : const TextStyle(
                  color: Colors.white54,
                  decoration: TextDecoration.lineThrough,
                ),
        );
        if (block == null) return line;
        final String reason = switch (block) {
          HabitReminderBlock.notificationsOff => journeyText(
            context,
            'Notifications are off',
            'Las notificaciones están desactivadas',
          ),
          HabitReminderBlock.remindersOff => journeyText(
            context,
            'Reminders are off',
            'Los recordatorios están desactivados',
          ),
          HabitReminderBlock.habitRemindersOff => journeyText(
            context,
            'Habit reminders are off',
            'Los recordatorios de hábitos están desactivados',
          ),
        };
        final bool asksPermission =
            block == HabitReminderBlock.notificationsOff;
        final String action = asksPermission
            ? journeyText(
                context,
                'Turn on notifications',
                'Activar notificaciones',
              )
            : journeyText(context, 'Open settings', 'Abrir ajustes');
        return Column(
          key: ValueKey<String>('rhythm-reminder-inactive-$habitId'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            line,
            Semantics(
              container: true,
              label: journeyText(
                context,
                'Reminder inactive. $reason.',
                'Recordatorio inactivo. $reason.',
              ),
              excludeSemantics: true,
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.notifications_off_outlined,
                    color: AppColors.memoryAmber,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(reason)),
                ],
              ),
            ),
            TextButton(
              key: ValueKey<String>('rhythm-reminder-inactive-action-$habitId'),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              onPressed: () => asksPermission
                  ? turnOnNotifications(context, ref)
                  : goToAppView(context, ref, AppView.settings),
              child: Text(action),
            ),
          ],
        );
      },
    );
  }
}
