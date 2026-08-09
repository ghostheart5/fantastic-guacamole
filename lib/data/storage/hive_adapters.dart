import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveAdapters {
  HiveAdapters._();

  static bool _registered = false;

  static void registerAll() {
    if (_registered) {
      return;
    }

    // GoalRepository uses JSON. Its former binary adapter remains legacy and
    // unregistered until a versioned migration can preserve every field.

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
