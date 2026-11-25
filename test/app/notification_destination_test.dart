import 'package:fantastic_guacamole/app/notification_destination.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/services/reflection_reminder_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every id a reminder producer registers must lead somewhere useful. The ids
/// below are built the way the producers build them, so renaming one at the
/// producing end fails here instead of silently landing on the default tab.
void main() {
  final habitPrefix = ReminderOrchestratorService.habitReminderPrefix;

  for (final (String id, NotificationDestination expected) in [
    // Goal reminders: the day-before reminder has no suffix; four more slots.
    ('goal_reminder_g1', NotificationDestination.goals),
    ('goal_reminder_g1_3d', NotificationDestination.goals),
    ('goal_reminder_g1_due', NotificationDestination.goals),
    ('goal_reminder_g1_close', NotificationDestination.goals),
    ('goal_reminder_g1_overdue', NotificationDestination.goals),
    // Rhythm reminders, per weekday, and the old shared 8 PM reminder.
    ('${habitPrefix}walk', NotificationDestination.habitCheckIns),
    ('${habitPrefix}walk_wd3', NotificationDestination.habitCheckIns),
    ('habit_reminder_daily', NotificationDestination.habitCheckIns),
    // Task reminders, from the planner's own id builders.
    (TaskReminderPlanner.startId('t1'), NotificationDestination.tasks),
    (TaskReminderPlanner.dueId('t1'), NotificationDestination.tasks),
    (TaskReminderPlanner.overdueId('t1'), NotificationDestination.tasks),
    (
      ReminderOrchestratorService.dailyPlanningReminderId,
      NotificationDestination.dailyPlanning,
    ),
    (
      ReflectionReminderService.notificationId,
      NotificationDestination.reflectionSchedule,
    ),
    ('streak_break_recovery_2026-11-20', NotificationDestination.activity),
    ('something_unmapped', NotificationDestination.fallback),
  ]) {
    test('"$id" opens ${expected.name}', () {
      expect(notificationDestinationFor(id), expected);
    });
  }

  test('a deleted item still opens the list it lived in', () {
    // Nothing is looked up: the id alone decides, so a goal, rhythm or task
    // removed after its reminder was registered lands on its list.
    expect(
      notificationDestinationFor('goal_reminder_deleted-goal_due'),
      NotificationDestination.goals,
    );
    expect(
      notificationDestinationFor('habit_reminder_deleted-habit_wd7'),
      NotificationDestination.habitCheckIns,
    );
    expect(
      notificationDestinationFor(TaskReminderPlanner.dueId('deleted-task')),
      NotificationDestination.tasks,
    );
  });

  test('tab destinations name the tab they open', () {
    expect(NotificationDestination.goals.view, AppView.goals);
    expect(NotificationDestination.dailyPlanning.view, AppView.smartPlanner);
    expect(NotificationDestination.tasks.view, AppView.timeline);
    expect(NotificationDestination.activity.view, AppView.progression);
    expect(NotificationDestination.fallback.view, AppView.timeline);
    // These open a screen over the current tab instead.
    expect(NotificationDestination.habitCheckIns.view, isNull);
    expect(NotificationDestination.reflectionSchedule.view, isNull);
  });
}
