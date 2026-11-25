import 'package:fantastic_guacamole/domain/entities/creator_handshake.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/features/creator/ui/creator_reminder_permission.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 11, 2, 15);

  CreatorMutationOperation task({DateTime? scheduledFor, DateTime? dueDate}) =>
      CreatorMutationOperation(
        operationId: 'op',
        kind: CreatorMutationKind.createTask,
        label: 'Task',
        task: CreatorTaskMutation(
          taskId: 't',
          creatorKind: 'Task',
          title: 'Call the clinic',
          description: null,
          priority: 3,
          difficulty: 3,
          energyRequired: 3,
          createdAt: now,
          scheduledFor: scheduledFor,
          dueDate: dueDate,
          recurrenceRule: RecurrenceRule.none,
        ),
      );

  ReminderOrchestratorPrefs prefs({required bool tasks}) =>
      ReminderOrchestratorPrefs(
        goalRemindersEnabled: true,
        habitRemindersEnabled: true,
        dailyPlanningEnabled: true,
        dailyPlanningHour: 7,
        dailyPlanningMinute: 30,
        taskRemindersEnabled: tasks,
      );

  test('a task that will get a reminder can remind', () {
    expect(
      creatorSaveCanRemind(
        [task(scheduledFor: now.add(const Duration(hours: 1)))],
        prefs(tasks: true),
        now: now,
      ),
      isTrue,
    );
    expect(
      creatorSaveCanRemind(
        [task(dueDate: now.add(const Duration(days: 2)))],
        prefs(tasks: true),
        now: now,
      ),
      isTrue,
    );
  });

  test('an undated or past task, or reminders off, does not', () {
    expect(
      creatorSaveCanRemind([task()], prefs(tasks: true), now: now),
      isFalse,
    );
    expect(
      creatorSaveCanRemind(
        [task(scheduledFor: now.subtract(const Duration(hours: 1)))],
        prefs(tasks: true),
        now: now,
      ),
      isFalse,
    );
    expect(
      creatorSaveCanRemind(
        [task(scheduledFor: now.add(const Duration(hours: 1)))],
        prefs(tasks: false),
        now: now,
      ),
      isFalse,
    );
  });
}
