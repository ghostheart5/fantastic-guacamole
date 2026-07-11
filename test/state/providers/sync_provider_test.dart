import 'dart:io';

import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
import 'package:fantastic_guacamole/data/services/backup_service.dart';
import 'package:fantastic_guacamole/data/services/sync_service.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:fantastic_guacamole/state/services/offline_sync_queue_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory hiveDirectory;
  late SharedPrefsStorage prefs;
  late HiveStorage<String> profileStorage;
  late _TestHiveStore hiveStore;
  late _MemoryTaskRepository repository;
  late _SequencedCloudBackupGateway gateway;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    hiveDirectory = await Directory.systemTemp.createTemp('chronospark_sync_provider_');
    Hive.init(hiveDirectory.path);

    prefs = SharedPrefsStorage(await SharedPreferences.getInstance());
    hiveStore = _TestHiveStore();
    profileStorage = HiveStorage<String>('profile_box', hive: hiveStore);
    repository = _MemoryTaskRepository();

    final BackupService backupService = BackupService(
      taskRepository: repository,
      profileStorage: profileStorage,
      prefs: prefs,
    );

    gateway = _SequencedCloudBackupGateway(<bool>[false, true, true]);

    container = ProviderContainer(
      overrides: [
        hiveStoreProvider.overrideWithValue(hiveStore),
        syncServiceProvider.overrideWithValue(SyncService(backup: backupService, gateway: gateway)),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await profileStorage.close();
    await Hive.close();
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  test('syncToCloudProvider returns false when upload fails', () async {
    await repository.saveTask(
      TaskEntity(id: 'task-1', title: 'Queue me', createdAt: DateTime.utc(2026, 7, 5)),
    );

    final bool first = await container.read(syncToCloudProvider.future);
    expect(first, isFalse);
    expect(gateway.uploadAttempts, 1);
  });

  test(
    'replayOfflineQueueProvider replays queued sync action and clears queue on success',
    () async {
      gateway.uploadShouldAlwaysSucceed = true;
      final OfflineSyncQueueService queue = OfflineSyncQueueService(
        HiveStorage<String>(HiveBoxes.offlineQueue, hive: hiveStore),
      );
      await queue.enqueue(
        actionType: 'sync_to_cloud',
        dedupeKey: 'sync_to_cloud',
        payload: const <String, dynamic>{},
      );

      expect(await queue.queuedCount(), 1);

      final int processed = await container.read(replayOfflineQueueProvider.future);
      expect(processed, 1);

      expect(await queue.queuedCount(), 0);
      expect(gateway.uploadAttempts, greaterThanOrEqualTo(1));
    },
  );

  test('replayOfflineQueueProvider keeps unknown action items queued', () async {
    final OfflineSyncQueueService queue = OfflineSyncQueueService(
      HiveStorage<String>(HiveBoxes.offlineQueue, hive: hiveStore),
    );
    await queue.enqueue(
      actionType: 'unknown_action',
      dedupeKey: 'unknown_action',
      payload: const <String, dynamic>{'sample': true},
    );

    expect(await queue.queuedCount(), 1);

    final int processed = await container.read(replayOfflineQueueProvider.future);
    expect(processed, 1);

    final int queuedAfterReplay = await queue.queuedCount();
    expect(queuedAfterReplay, 1);
  });
}

class _SequencedCloudBackupGateway implements CloudBackupGateway {
  _SequencedCloudBackupGateway(this._uploadOutcomes);

  final List<bool> _uploadOutcomes;
  bool uploadShouldAlwaysSucceed = false;
  int uploadAttempts = 0;
  Map<String, dynamic> fullBackup = <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> downloadBackup() async {
    return fullBackup;
  }

  @override
  Future<Map<String, dynamic>> downloadTasks() async {
    return const <String, dynamic>{};
  }

  @override
  Future<bool> uploadBackup(Map<String, dynamic> backup) async {
    uploadAttempts += 1;
    if (uploadShouldAlwaysSucceed) {
      fullBackup = backup;
      return true;
    }
    final bool outcome = uploadAttempts <= _uploadOutcomes.length
        ? _uploadOutcomes[uploadAttempts - 1]
        : true;
    if (outcome) {
      fullBackup = backup;
    }
    return outcome;
  }

  @override
  Future<bool> uploadTasks(Map<String, dynamic> backup) async {
    return true;
  }
}

class _MemoryTaskRepository implements ITaskRepository {
  final Map<String, TaskEntity> _tasks = <String, TaskEntity>{};

  @override
  Future<void> deleteTask(String id) async {
    _tasks.remove(id);
  }

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    return _tasks.values.toList(growable: false);
  }

  @override
  Future<TaskEntity?> getTaskById(String id) async {
    return _tasks[id];
  }

  @override
  Future<void> saveTask(TaskEntity task) async {
    _tasks[task.id] = task;
  }
}

class _TestHiveStore implements HiveStore {
  @override
  Future<void> clearBox(String key) async {
    final Box<String> box = await openBox<String>(key);
    await box.clear();
  }

  @override
  Future<void> closeBox(String key) async {
    if (Hive.isBoxOpen(key)) {
      await Hive.box<String>(key).close();
    }
  }

  @override
  Box<T> box<T>(String key) {
    return Hive.box<T>(key);
  }

  @override
  Future<void> init() async {}

  @override
  bool isBoxOpen(String key) {
    return Hive.isBoxOpen(key);
  }

  @override
  Future<Box<T>> openBox<T>(String key) {
    if (Hive.isBoxOpen(key)) {
      return Future<Box<T>>.value(Hive.box<T>(key));
    }
    return Hive.openBox<T>(key);
  }
}
