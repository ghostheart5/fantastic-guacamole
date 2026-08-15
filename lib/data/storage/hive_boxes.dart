import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';

class HiveBoxes {
  HiveBoxes._();

  static const String tasks = 'tasks_box';
  static const String goals = 'goals_box';
  static const String habits = 'habits_box';
  static const String habitOccurrences = 'habit_occurrences_v2';
  static const String projects = 'projects_box';
  static const String routines = 'routines_box';
  static const String subtasks = 'subtasks_box';
  static const String progression = 'progression_box';
  static const String dailyPlans = 'daily_plans_box';
  static const String offlineQueue = 'offline_queue_box';
  static const String notifications = 'notifications_box';
  static const String timeline = 'timeline_box';
  static const String cache = 'cache_box';

  static const Set<String> encryptedBoxes = <String>{
    tasks,
    goals,
    habits,
    habitOccurrences,
    projects,
    routines,
    subtasks,
    progression,
    dailyPlans,
    offlineQueue,
    notifications,
    timeline,
    cache,
  };

  /// Names an active V2 account-local box without consulting auth directly.
  ///
  /// A separate box is deliberate: repositories that enumerate their box must
  /// never discover another account's IDs or payloads and then filter them.
  /// An unsafe lifecycle transition has no namespace and therefore cannot
  /// construct a storage target.
  static String accountScoped(String baseBox, AccountStorageScope scope) {
    final String? namespace = scope.v2Namespace;
    if (namespace == null) {
      throw StateError(
        'Cannot construct account storage while the session boundary is unsafe.',
      );
    }
    return accountScopedNamespace(baseBox, namespace);
  }

  static String accountScopedNamespace(String baseBox, String v2Namespace) {
    if (!v2Namespace.startsWith('v2.')) {
      throw ArgumentError.value(v2Namespace, 'v2Namespace');
    }
    return '$baseBox.$v2Namespace';
  }

  static bool isEncryptedBox(String box) {
    return encryptedBoxes.contains(box) ||
        encryptedBoxes.any((String baseBox) => box.startsWith('$baseBox.v2.'));
  }
}
