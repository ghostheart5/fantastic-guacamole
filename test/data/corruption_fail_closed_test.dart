import 'dart:io';

import 'package:fantastic_guacamole/core/errors/app_exception.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
import 'package:fantastic_guacamole/data/repositories/insight_repository.dart';
import 'package:fantastic_guacamole/data/repositories/project_repository.dart';
import 'package:fantastic_guacamole/data/repositories/subtask_repository.dart';
import 'package:fantastic_guacamole/data/repositories/timeline_repository.dart';
import 'package:fantastic_guacamole/data/services/workspace_store_service.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/services/credit_service.dart';
import 'package:fantastic_guacamole/state/services/offline_sync_queue_service.dart';
import 'package:fantastic_guacamole/state/services/preference_service.dart';
import 'package:fantastic_guacamole/tutorial/mission/mission_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryPrefsStore implements SharedPrefsStore {
  _MemoryPrefsStore(this.values);

  final Map<String, String> values;

  @override
  Future<void> clear() async => values.clear();
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<void> init() async {}
  @override
  String? load(String key) => values[key];
  @override
  Future<void> save(String key, String value) async => values[key] = value;
}

class _TestHiveStore implements HiveStore {
  const _TestHiveStore();

  @override
  Box<T> box<T>(String key) => Hive.box<T>(key);

  @override
  Future<void> clearBox(String key) async => Hive.box<dynamic>(key).clear();

  @override
  Future<void> closeBox(String key) async => Hive.box<dynamic>(key).close();

  @override
  Future<void> init() async {}

  @override
  bool isBoxOpen(String key) => Hive.isBoxOpen(key);

  @override
  Future<Box<T>> openBox<T>(String key) => Hive.openBox<T>(key);
}

HiveStorage<String> _hiveStorage(String key) =>
    HiveStorage<String>(key, hive: const _TestHiveStore());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Hive.init(
      Directory.systemTemp.createTempSync('chronospark-corruption-').path,
    );
  });

  test(
    'shared preference JSON distinguishes an absent key from corruption',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPrefsStorage storage = SharedPrefsStorage(
        await SharedPreferences.getInstance(),
      );
      expect(storage.getJson('preferences'), isEmpty);
      await storage.setString('preferences', '{bad-json');
      expect(
        () => storage.getJson('preferences'),
        throwsA(isA<StorageException>()),
      );
    },
  );

  test(
    'project and subtask corruption does not become first-run data',
    () async {
      final HiveStorage<String> projects = _hiveStorage('corrupt_projects');
      final HiveStorage<String> subtasks = _hiveStorage('corrupt_subtasks');
      await projects.put('projects_v1', '{bad');
      await subtasks.put('subtasks_v1', '{bad');

      expect(
        () => ProjectRepository(projects).getProjects(),
        throwsA(isA<StorageException>()),
      );
      expect(
        () => SubtaskRepository(subtasks).getSubtasks(),
        throwsA(isA<StorageException>()),
      );
    },
  );

  test(
    'timeline and insight corruption is not converted to an empty collection',
    () async {
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'corruption',
      );
      final _MemoryPrefsStore store = _MemoryPrefsStore(<String, String>{
        'timeline_events_v2.${scope.v2Namespace}': '{bad',
        'insights_v1':
            '[{"id":"i","title":"x","summary":"x","createdAt":"bad","tags":[]}]',
      });
      expect(
        TimelineRepository(store, scope).getEvents,
        throwsA(isA<StorageException>()),
      );
      expect(
        InsightRepository(store).getInsights,
        throwsA(isA<StorageException>()),
      );
    },
  );

  test(
    'corrupt workspace and mission state do not seed initial data',
    () async {
      final SecureStore secure = SecureStore(
        backend: InMemorySecureStoreBackend(),
      );
      await secure.writeString('workspace_creator_v1', '{bad');
      await expectLater(
        WorkspaceStoreService(store: secure).loadCreatorState(),
        throwsA(isA<StorageException>()),
      );

      final _MemoryPrefsStore missionStore = _MemoryPrefsStore(<String, String>{
        MissionRepository.storageKey: '{bad',
      });
      await expectLater(
        MissionRepository(store: missionStore).load(),
        throwsA(isA<StorageException>()),
      );
    },
  );

  test(
    'corrupt credit wallet and offline queue are not replaced by defaults',
    () async {
      final _MemoryPrefsStore walletStore = _MemoryPrefsStore(<String, String>{
        'ai_credit_wallet': '{bad',
      });
      await expectLater(
        CreditService(prefs: walletStore).loadWallet(premium: false),
        throwsA(isA<StorageException>()),
      );
      expect(walletStore.load('ai_credit_wallet'), '{bad');

      final HiveStorage<String> queueStorage = _hiveStorage(
        'corrupt_offline_queue',
      );
      await queueStorage.put(OfflineSyncQueueService.storageKey, '{bad');
      final OfflineSyncQueueService queue = OfflineSyncQueueService(
        queueStorage,
      );
      await expectLater(queue.loadQueue(), throwsA(isA<StorageException>()));
      await expectLater(
        queue.enqueue(actionType: 'task_update', dedupeKey: 'task-1'),
        throwsA(isA<StorageException>()),
      );
      expect(queueStorage.get(OfflineSyncQueueService.storageKey), '{bad');
    },
  );

  test(
    'corrupt user preferences cannot be overwritten by a mutation',
    () async {
      await SharedPrefsService.init();
      await SharedPrefsService.save('user_preferences_json', '{bad');
      final PreferenceService service = PreferenceService();

      expect(service.getUserPreferences, throwsA(isA<StorageException>()));
      await expectLater(
        service.setUserPreference('density', 'compact'),
        throwsA(isA<StorageException>()),
      );
      expect(SharedPrefsService.load('user_preferences_json'), '{bad');
    },
  );
}
