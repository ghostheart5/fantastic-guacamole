import 'package:fantastic_guacamole/data/storage/adapters/goal_entity_adapter.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveAdapters {
  HiveAdapters._();

  static bool _registered = false;

  static void registerAll() {
    if (_registered) {
      return;
    }

    if (!Hive.isAdapterRegistered(101)) {
      Hive.registerAdapter(GoalEntityAdapter());
    }

    _registered = true;
  }

  static Future<void> openDefaultBoxes() async {
    const List<String> defaultStringBoxes = <String>[
      HiveBoxes.tasks,
      HiveBoxes.goals,
      HiveBoxes.habits,
      HiveBoxes.progression,
      HiveBoxes.dailyPlans,
      HiveBoxes.offlineQueue,
      HiveBoxes.flowmap,
      HiveBoxes.notifications,
      HiveBoxes.timeline,
      HiveBoxes.cache,
    ];
    for (final String box in defaultStringBoxes) {
      if (!Hive.isBoxOpen(box)) {
        await Hive.openBox<String>(box);
      }
    }
  }
}
