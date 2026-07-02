import 'package:fantastic_guacamole/core/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
import 'package:fantastic_guacamole/data/services/backup_service.dart';
import 'package:fantastic_guacamole/data/services/sync_service.dart';
import 'package:fantastic_guacamole/features/tasks/models/tasks_models.dart';
import 'package:fantastic_guacamole/features/user/models/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _sharedPrefsProvider = FutureProvider<SharedPrefsStorage>((ref) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return SharedPrefsStorage(prefs);
});

final _backupServiceProvider = Provider<BackupService?>((ref) {
  final AsyncValue<SharedPrefsStorage> prefsAsync = ref.watch(_sharedPrefsProvider);
  return prefsAsync.whenOrNull(
    data: (SharedPrefsStorage prefs) => BackupService(
      taskStorage: HiveStorage<TaskModel>('tasks', hive: const HiveStoreAdapter()),
      userStorage: HiveStorage<UserModel>('users', hive: const HiveStoreAdapter()),
      prefs: prefs,
    ),
  );
});

final syncServiceProvider = Provider<SyncService?>((ref) {
  final AsyncValue<SharedPrefsStorage> prefsAsync = ref.watch(_sharedPrefsProvider);
  final BackupService? backup = ref.watch(_backupServiceProvider);
  return prefsAsync.whenOrNull(
    data: (SharedPrefsStorage prefs) => backup == null
        ? null
        : SyncService(
            backup: backup,
            prefs: prefs,
            taskStorage: HiveStorage<TaskModel>('tasks', hive: const HiveStoreAdapter()),
            userStorage: HiveStorage<UserModel>('users', hive: const HiveStoreAdapter()),
          ),
  );
});

final syncToCloudProvider = FutureProvider<bool>((ref) async {
  return ref.read(syncServiceProvider)?.syncToCloud() ?? Future<bool>.value(false);
});

final restoreFromCloudProvider = FutureProvider<bool>((ref) async {
  return ref.read(syncServiceProvider)?.restoreFromCloud() ?? Future<bool>.value(false);
});
