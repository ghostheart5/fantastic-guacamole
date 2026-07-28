import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hive boxes coverage', () {
    test('declares all expected box names', () {
      expect(HiveBoxes.tasks, 'tasks_box');
      expect(HiveBoxes.goals, 'goals_box');
      expect(HiveBoxes.habits, 'habits_box');
      expect(HiveBoxes.projects, 'projects_box');
      expect(HiveBoxes.routines, 'routines_box');
      expect(HiveBoxes.subtasks, 'subtasks_box');
      expect(HiveBoxes.progression, 'progression_box');
      expect(HiveBoxes.dailyPlans, 'daily_plans_box');
      expect(HiveBoxes.offlineQueue, 'offline_queue_box');
      expect(HiveBoxes.notifications, 'notifications_box');
      expect(HiveBoxes.timeline, 'timeline_box');
      expect(HiveBoxes.cache, 'cache_box');
    });

    test('encryptedBoxes contains every declared box once', () {
      const Set<String> expected = <String>{
        HiveBoxes.tasks,
        HiveBoxes.goals,
        HiveBoxes.habits,
        HiveBoxes.projects,
        HiveBoxes.routines,
        HiveBoxes.subtasks,
        HiveBoxes.progression,
        HiveBoxes.dailyPlans,
        HiveBoxes.offlineQueue,
        HiveBoxes.notifications,
        HiveBoxes.timeline,
        HiveBoxes.cache,
      };

      expect(HiveBoxes.encryptedBoxes, expected);
      expect(HiveBoxes.encryptedBoxes.length, 12);
    });
  });
}
