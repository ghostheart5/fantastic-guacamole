import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';

class HiveBoxes {
  HiveBoxes._();

  static const String tasks = 'tasks_box';
  static const String goals = 'goals_box';
  static const String habits = 'habits_box';
  static const String taskOccurrences = 'task_occurrences_v2';
  static const String projects = 'projects_box';
  static const String routines = 'routines_box';
  static const String subtasks = 'subtasks_box';
  static const String progression = 'progression_box';
  static const String dailyPlans = 'daily_plans_box';
  static const String offlineQueue = 'offline_queue_box';
  static const String notifications = 'notifications_box';
  static const String timeline = 'timeline_box';
  static const String cache = 'cache_box';

  static String accountScoped(String baseBox, AccountStorageScope scope) {
    final String? namespace = scope.v2Namespace;
    if (namespace == null) {
      throw StateError(
        'Cannot construct account storage during an unsafe transition.',
      );
    }
    return '$baseBox.$namespace';
  }
}
