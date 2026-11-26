import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/domain/entities/creator_handshake.dart';
import 'package:fantastic_guacamole/features/permissions/notification_permission_flow.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether anything the Creator just saved can send a reminder: a goal with
/// a target date while goal reminders are on, a habit given a reminder time
/// while habit reminders are on, or a task whose start time or deadline gets
/// a reminder while task reminders are on. Add each new kind of item that
/// gets a reminder here.
bool creatorSaveCanRemind(
  Iterable<CreatorMutationOperation> saved,
  ReminderOrchestratorPrefs prefs, {
  DateTime? now,
}) => saved.any(
  (CreatorMutationOperation operation) =>
      (prefs.goalRemindersEnabled && operation.goal?.targetDate != null) ||
      (prefs.habitRemindersEnabled &&
          operation.habit?.reminderMinutes != null) ||
      switch (operation.taskMutation) {
        final CreatorTaskMutation task => TaskReminderPlanner.wouldRemind(
          scheduledFor: task.scheduledFor,
          dueDate: task.dueDate,
          prefs: prefs,
          now: now ?? DateTime.now(),
        ),
        null => false,
      },
);

/// Called after the Creator has saved [saved]: asks once, in context, for
/// notification permission when one of them can remind the person.
Future<void> askForRemindersAfterCreatorSave(
  BuildContext context,
  WidgetRef ref,
  Iterable<CreatorMutationOperation> saved,
) async {
  if (!context.mounted) return;
  final ReminderOrchestratorPrefs prefs = ref
      .read(settingsUiActionsProvider)
      .loadAdvancedReminderPrefs();
  if (!creatorSaveCanRemind(saved, prefs)) return;
  await ensureNotificationPermission(context, ref, afterSave: true);
}

/// The same question after the first-run guide saved its first task, which
/// is followed by opening My plan. A failure here never stops that.
Future<void> askForGuidedFirstTaskReminders(
  BuildContext context,
  WidgetRef ref,
  Iterable<CreatorMutationOperation> saved,
) async {
  try {
    await askForRemindersAfterCreatorSave(context, ref, saved);
  } on Object {
    Logger.warn('Reminder permission question after the guided task failed.');
  }
}
