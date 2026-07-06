import 'package:hive_flutter/hive_flutter.dart';

class HiveAdapters {
  HiveAdapters._();

  static bool _registered = false;

  static void registerAll() {
    if (_registered) {
      return;
    }

    // Register custom Hive type adapters here when new types are introduced.
    _registered = true;
  }

  static Future<void> openDefaultBoxes() async {
    if (!Hive.isBoxOpen('tasks_box')) {
      await Hive.openBox<String>('tasks_box');
    }
  }
}
