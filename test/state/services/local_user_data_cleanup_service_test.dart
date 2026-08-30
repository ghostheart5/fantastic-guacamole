import 'dart:async';
import 'dart:io';

import 'package:fantastic_guacamole/core/async/keyed_mutation_coordinator.dart';
import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/data/repositories/note_repository.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/state/services/local_user_data_cleanup_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'local_user_data_cleanup_test_',
    );
    await Hive.close();
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'inspects an already-open string task box without a Hive type error',
    () async {
      final Box<String> tasks = await Hive.openBox<String>(HiveBoxes.tasks);
      await tasks.put('task-1', '{"id":"task-1"}');
      final LocalUserDataCleanupService service = LocalUserDataCleanupService(
        hive: const _DirectHiveStore(),
        secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
        preferences: _MemoryPreferences(),
        sensitivePreferences: _MemoryPreferences(),
        notifications: NotificationScheduler(),
      );

      expect(await service.hasUnownedAccountData(), isTrue);
      expect(Hive.box<String>(HiveBoxes.tasks).get('task-1'), isNotNull);
    },
  );

  test(
    'clears departing account data while preserving device-global and other-owner scoped state',
    () async {
      final _RecordingHiveStore hive = _RecordingHiveStore();
      final InMemorySecureStoreBackend backend = InMemorySecureStoreBackend();
      final SecureStore secureStore = SecureStore(backend: backend);
      final _MemoryPreferences preferences = _MemoryPreferences();
      final _MemoryPreferences sensitivePreferences = _MemoryPreferences();
      final String namespace = AccountDataRegistry.accountNamespace(
        'account-a',
      );

      for (final String key in AccountDataRegistry.secureExactKeysForAccount(
        'account-a',
      )) {
        await secureStore.writeString(key, 'private');
      }
      await secureStore.writeString(
        AccountDataRegistry.notificationSecureKeyFor('account-a'),
        '[]',
      );
      await secureStore.writeString(
        'si_engine_state_v2.$namespace.console.thread-1',
        'private',
      );
      await secureStore.writeString(
        AccountDataRegistry.notificationSecureKeyFor('account-b'),
        'other-owner',
      );
      await secureStore.writeString('hive_aes_key', 'device-global');
      await secureStore.writeString(
        'cloud_backup_encryption_key_v1',
        'legacy-recovery-key',
      );
      await secureStore.writeString(
        'cloud_backup_encryption_key_v1_owner_digest',
        AccountDataRegistry.accountDigest('account-a'),
      );
      final String scopedBackupKey =
          'cloud_backup_encryption_key_v2.${AccountDataRegistry.accountDigest('account-a')}';
      await secureStore.writeString(scopedBackupKey, 'account-recovery-key');

      for (final String key
          in AccountDataRegistry.preferenceExactKeysForAccount('account-a')) {
        await preferences.save(key, 'private');
      }
      await preferences.save(
        'chronospark.trajectory.forecast_ledger.v1.$namespace.corrupt.1',
        'private',
      );
      for (final String key in AccountDataRegistry.deviceGlobalPreferenceKeys) {
        await preferences.save(key, 'device-global');
      }

      for (final String key
          in AccountDataRegistry.sensitivePreferenceKeysForAccount(
            'account-a',
          )) {
        await sensitivePreferences.save(key, 'private');
      }
      final String otherMemory =
          'governed_memories_v2.${AccountDataRegistry.accountNamespace('account-b')}';
      await sensitivePreferences.save(otherMemory, 'other-owner');

      final LocalUserDataCleanupService service = LocalUserDataCleanupService(
        hive: hive,
        secureStore: secureStore,
        preferences: preferences,
        sensitivePreferences: sensitivePreferences,
        notifications: NotificationScheduler(),
      );

      await service.clearForAccountSwitch('account-a');

      expect(
        hive.clearedBoxes,
        containsAll(AccountDataRegistry.hiveBoxesForAccount('account-a')),
      );
      expect(
        await secureStore.readString(
          'si_engine_state_v2.$namespace.console.thread-1',
        ),
        isNull,
      );
      expect(await secureStore.readString('hive_aes_key'), 'device-global');
      expect(
        await secureStore.readString('cloud_backup_encryption_key_v1'),
        'legacy-recovery-key',
      );
      expect(
        await secureStore.readString(
          'cloud_backup_encryption_key_v1_owner_digest',
        ),
        AccountDataRegistry.accountDigest('account-a'),
      );
      expect(
        await secureStore.readString(scopedBackupKey),
        'account-recovery-key',
      );
      expect(
        await secureStore.readString(
          AccountDataRegistry.notificationSecureKeyFor('account-b'),
        ),
        'other-owner',
      );
      for (final String key in AccountDataRegistry.deviceGlobalPreferenceKeys) {
        expect(preferences.load(key), 'device-global', reason: key);
      }
      expect(preferences.load('notes_v1'), isNull);
      expect(preferences.load('notes_v1_corrupt_backup'), isNull);
      expect(sensitivePreferences.load(otherMemory), 'other-owner');
      expect(
        sensitivePreferences.load('governed_memories_v2.$namespace'),
        isNull,
      );
    },
  );

  test(
    'uses the stored owner marker when cleanup omits an account ID',
    () async {
      final _RecordingHiveStore hive = _RecordingHiveStore();
      final SecureStore secureStore = SecureStore(
        backend: InMemorySecureStoreBackend(),
      );
      final _MemoryPreferences preferences = _MemoryPreferences();
      final String namespace = AccountDataRegistry.accountNamespace(
        'account-a',
      );
      await secureStore.writeString(
        AccountDataRegistry.accountBoundaryOwnerKey,
        'account-a',
      );
      await secureStore.writeString(
        AccountDataRegistry.notificationSecureKeyFor('account-a'),
        '[]',
      );
      await preferences.save(
        'chronospark.operating.history.v1.$namespace',
        'private',
      );

      final LocalUserDataCleanupService service = LocalUserDataCleanupService(
        hive: hive,
        secureStore: secureStore,
        preferences: preferences,
        sensitivePreferences: _MemoryPreferences(),
        notifications: NotificationScheduler(),
      );

      await service.clearForAccountSwitch();

      expect(hive.clearedBoxes, contains('task_occurrences_v2.$namespace'));
      expect(
        preferences.load('chronospark.operating.history.v1.$namespace'),
        isNull,
      );
      expect(
        await secureStore.readString(
          AccountDataRegistry.accountBoundaryOwnerKey,
        ),
        isNull,
      );
    },
  );

  test('account cleanup cannot race with an in-flight Notes write', () async {
    final KeyedMutationCoordinator coordinator = KeyedMutationCoordinator();
    final Completer<void> saveEntered = Completer<void>();
    final Completer<void> releaseSave = Completer<void>();
    final _MemoryPreferences preferences = _MemoryPreferences(
      blockedSaveKey: 'notes_v1',
      saveEntered: saveEntered,
      releaseSave: releaseSave,
    );
    final NoteRepository notes = NoteRepository(
      preferences,
      mutationCoordinator: coordinator,
    );
    final LocalUserDataCleanupService service = LocalUserDataCleanupService(
      hive: _RecordingHiveStore(),
      secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
      preferences: preferences,
      sensitivePreferences: _MemoryPreferences(),
      notifications: NotificationScheduler(),
      mutationCoordinator: coordinator,
    );

    final Future<void> save = notes.saveNote(
      NoteEntity(
        id: 'departing-note',
        title: 'Private note',
        createdAt: DateTime.utc(2026, 8, 30, 12),
      ),
    );
    await saveEntered.future;
    bool cleanupCompleted = false;
    final Future<void> cleanup = service
        .clearForAccountSwitch('account-a')
        .whenComplete(() => cleanupCompleted = true);
    await Future<void>.delayed(Duration.zero);
    expect(cleanupCompleted, isFalse);

    releaseSave.complete();
    await Future.wait(<Future<void>>[save, cleanup]);

    expect(preferences.load('notes_v1'), isNull);
    expect(await notes.getNotes(), isEmpty);
  });
}

class _DirectHiveStore implements HiveStore {
  const _DirectHiveStore();

  @override
  Future<void> init() async {}

  @override
  bool isBoxOpen(String key) => Hive.isBoxOpen(key);

  @override
  Future<Box<T>> openBox<T>(String key) {
    if (Hive.isBoxOpen(key)) {
      return Future<Box<T>>.value(Hive.box<T>(key));
    }
    return Hive.openBox<T>(key);
  }

  @override
  Box<T> box<T>(String key) => Hive.box<T>(key);

  @override
  Future<void> clearBox(String key) async {
    final Box<String> target = Hive.isBoxOpen(key)
        ? Hive.box<String>(key)
        : await Hive.openBox<String>(key);
    await target.clear();
  }

  @override
  Future<void> closeBox(String key) async {
    if (Hive.isBoxOpen(key)) await Hive.box<String>(key).close();
  }
}

class _MemoryPreferences
    implements SharedPrefsStore, EnumerableSharedPrefsStore {
  _MemoryPreferences({this.blockedSaveKey, this.saveEntered, this.releaseSave});

  final String? blockedSaveKey;
  final Completer<void>? saveEntered;
  final Completer<void>? releaseSave;
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> init() async {}

  @override
  Future<void> save(String key, String value) async {
    if (key == blockedSaveKey) {
      if (!(saveEntered?.isCompleted ?? true)) saveEntered!.complete();
      await releaseSave?.future;
    }
    _values[key] = value;
  }

  @override
  String? load(String key) => _values[key];

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> clear() async {
    _values.clear();
  }

  @override
  Future<Set<String>> keys() async => _values.keys.toSet();
}

class _RecordingHiveStore implements HiveStore {
  final Set<String> clearedBoxes = <String>{};

  @override
  Box<T> box<T>(String key) => throw UnimplementedError();

  @override
  Future<void> clearBox(String key) async => clearedBoxes.add(key);

  @override
  Future<void> closeBox(String key) async {}

  @override
  Future<void> init() async {}

  @override
  bool isBoxOpen(String key) => false;

  @override
  Future<Box<T>> openBox<T>(String key) => throw UnimplementedError();
}
