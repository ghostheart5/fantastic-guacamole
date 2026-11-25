import 'package:fantastic_guacamole/features/permissions/notification_permission_flow.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Called after a task is saved with [scheduledFor] and [dueDate]: asks once,
/// in context, for notification permission when the task gets a reminder.
/// Save first, ask after.
Future<void> askForRemindersAfterTaskSave(
  BuildContext context,
  WidgetRef ref, {
  required DateTime? scheduledFor,
  required DateTime? dueDate,
}) async {
  if (!context.mounted) return;
  final ReminderOrchestratorPrefs prefs;
  try {
    prefs = ref.read(settingsUiActionsProvider).loadAdvancedReminderPrefs();
  } on Object {
    // Without readable account preferences there is nothing to ask about;
    // the task itself is already saved.
    return;
  }
  if (!TaskReminderPlanner.wouldRemind(
    scheduledFor: scheduledFor,
    dueDate: dueDate,
    prefs: prefs,
    now: DateTime.now(),
  )) {
    return;
  }
  await ensureNotificationPermission(context, ref);
}
