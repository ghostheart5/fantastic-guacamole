import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:hive/hive.dart';
import 'package:fantastic_guacamole/core/storage/storage_keys.dart';

class StorageMigration {
  static const int latestVersion = 2;

  static Future<void> run() async {
    final box = await Hive.openBox<dynamic>(StorageKeys.settings);

    final currentVersion =
        box.get(StorageKeys.storageVersion, defaultValue: 0) as int? ?? 0;

    Logger.log('StorageMigration', 'Current version → $currentVersion');

    if (currentVersion < 1) {
      await _migrateV1();
    }

    if (currentVersion < 2) {
      await _migrateV2();
    }

    await box.put(StorageKeys.storageVersion, latestVersion);

    Logger.log('StorageMigration', 'Updated to version $latestVersion');
  }

  static Future<void> _migrateV1() async {
    Logger.log('StorageMigration', 'V1: Initializing storage');
    final themeBox = await Hive.openBox<dynamic>(StorageKeys.theme);
    await themeBox.put('current_theme', 'default');
  }

  static Future<void> _migrateV2() async {
    Logger.log('StorageMigration', 'V2: Cleaning old notification data');
    final notifBox = await Hive.openBox<dynamic>(StorageKeys.notifications);
    await notifBox.clear();
  }
}
