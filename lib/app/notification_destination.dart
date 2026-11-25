import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/services/reflection_reminder_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';

/// Where tapping a reminder takes the person.
enum NotificationDestination {
  /// Goals. The screen cannot bring one goal into view, so a goal reminder
  /// opens the list.
  goals(AppView.goals),
  dailyPlanning(AppView.smartPlanner),

  /// The rhythm check-in list, opened over the current tab.
  habitCheckIns(null),

  /// My plan, which lists tasks. No screen shows a single task on its own.
  tasks(AppView.timeline),

  /// The Schedule, opened over the current tab.
  reflectionSchedule(null),
  activity(AppView.progression),
  fallback(AppView.timeline);

  const NotificationDestination(this.view);

  /// The tab to open, or null when a screen opens over the current one.
  final AppView? view;
}

/// The destination for a reminder id. The payload is the id itself, so it is
/// read with the producers' own id rules. Nothing is looked up: a reminder
/// whose goal, rhythm or task was deleted still opens the list it lived in.
NotificationDestination notificationDestinationFor(String notificationId) {
  if (ReminderOrchestratorService.ownsGoalReminderId(notificationId)) {
    return NotificationDestination.goals;
  }
  if (notificationId == ReminderOrchestratorService.dailyPlanningReminderId) {
    return NotificationDestination.dailyPlanning;
  }
  // Per rhythm, per chosen weekday, and the old shared habit_reminder_daily.
  if (ReminderOrchestratorService.ownsHabitReminderId(notificationId)) {
    return NotificationDestination.habitCheckIns;
  }
  if (TaskReminderPlanner.ownsId(notificationId)) {
    return NotificationDestination.tasks;
  }
  if (notificationId == ReflectionReminderService.notificationId) {
    return NotificationDestination.reflectionSchedule;
  }
  // ProfileController's streak recovery ids (its prefix is private there).
  if (notificationId.startsWith('streak_break_recovery_')) {
    return NotificationDestination.activity;
  }
  return NotificationDestination.fallback;
}
