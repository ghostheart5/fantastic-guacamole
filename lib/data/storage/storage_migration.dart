import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/storage/storage_keys.dart';
import 'package:hive/hive.dart';

class StorageMigration {
  static const int latestVersion = 2;

  static Future<void> run() async {
    final box = await Hive.openBox<dynamic>(StorageKeys.settings);

    final Object? rawVersion = box.get(StorageKeys.storageVersion);
    final int currentVersion = _safeVersion(rawVersion);

    Logger.log('StorageMigration', 'Current version → $currentVersion');

    if (currentVersion > latestVersion) {
      Logger.warn(
        'StorageMigration: Found future storage version $currentVersion; skipping migration to avoid data loss.',
      );
      return;
    }

    if (currentVersion < 1) {
      await _migrateV1();
    }

    if (currentVersion < 2) {
      await _migrateV2();
    }

    await box.put(StorageKeys.storageVersion, latestVersion);

    Logger.log('StorageMigration', 'Updated to version $latestVersion');
  }

  static int _safeVersion(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }
    return 0;
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
