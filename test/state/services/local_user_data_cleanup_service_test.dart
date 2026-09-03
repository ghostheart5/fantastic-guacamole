import 'dart:async';
import 'dart:io';

import 'package:fantastic_guacamole/core/async/keyed_mutation_coordinator.dart';
import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/note_repository.dart';
import 'package:fantastic_guacamole/data/storage/account_scoped_shared_prefs_store.dart';
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
        includeLegacyOwnedData: true,
      )) {
        await secureStore.writeString(key, 'private');
      }
      await secureStore.writeString(
        AccountDataRegistry.accountBoundaryOwnerKey,
        'account-a',
      );
      await secureStore.writeString(
        AccountDataRegistry.notificationSecureKeyFor('account-a'),
        '[]',
      );
      await secureStore.writeString(
        'si_engine_state_v2.$namespace.console.thread-1',
        'private',
      );
      final String pendingPurchaseOwnerKey =
          '${AccountDataRegistry.pendingPurchaseOwnerSecureKeyPrefix}'
          'chronospark_premium_monthly';
      await secureStore.writeString(pendingPurchaseOwnerKey, 'owner-digest');
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
          in AccountDataRegistry.preferenceExactKeysForAccount(
            'account-a',
            includeLegacyOwnedData: true,
          )) {
        await preferences.save(key, 'private');
      }
      final String otherNotes =
          'notes_v1.${AccountDataRegistry.accountNamespace('account-b')}';
      await preferences.save(otherNotes, 'other-owner');
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
            includeLegacyOwnedData: true,
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
        containsAll(
          AccountDataRegistry.hiveBoxesForAccount(
            'account-a',
            includeLegacyOwnedData: true,
          ),
        ),
      );
      expect(
        hive.clearedBoxes,
        isNot(
          contains(
            'tasks_box.${AccountDataRegistry.accountNamespace('account-b')}',
          ),
        ),
      );
      expect(
        await secureStore.readString(
          'si_engine_state_v2.$namespace.console.thread-1',
        ),
        isNull,
      );
      expect(await secureStore.readString(pendingPurchaseOwnerKey), isNull);
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
      expect(preferences.load(otherNotes), 'other-owner');
      expect(sensitivePreferences.load(otherMemory), 'other-owner');
      expect(
        sensitivePreferences.load('governed_memories_v2.$namespace'),
        isNull,
      );
    },
  );

  test('clearing a non-legacy owner deletes only its scoped data', () async {
    final _RecordingHiveStore hive = _RecordingHiveStore();
    final SecureStore secureStore = SecureStore(
      backend: InMemorySecureStoreBackend(),
    );
    final _MemoryPreferences preferences = _MemoryPreferences();
    final _MemoryPreferences sensitivePreferences = _MemoryPreferences();
    final String namespaceA = AccountDataRegistry.accountNamespace('account-a');
    final String namespaceB = AccountDataRegistry.accountNamespace('account-b');
    final AccountStorageScope scopeA = AccountStorageScope.authenticated(
      'account-a',
    );
    final AccountStorageScope scopeB = AccountStorageScope.authenticated(
      'account-b',
    );
    final SecureStore secureA = secureStore.forAccount(scopeA);
    final SecureStore secureB = secureStore.forAccount(scopeB);
    final AccountScopedSharedPrefsStore preferencesA =
        AccountScopedSharedPrefsStore(delegate: preferences, scope: scopeA);
    final AccountScopedSharedPrefsStore preferencesB =
        AccountScopedSharedPrefsStore(delegate: preferences, scope: scopeB);
    final AccountScopedSharedPrefsStore sensitiveA =
        AccountScopedSharedPrefsStore(
          delegate: sensitivePreferences,
          scope: scopeA,
        );
    final AccountScopedSharedPrefsStore sensitiveB =
        AccountScopedSharedPrefsStore(
          delegate: sensitivePreferences,
          scope: scopeB,
        );

    await secureStore.writeString(
      AccountDataRegistry.accountBoundaryOwnerKey,
      'account-a',
    );
    await secureStore.writeString('identity_id', 'legacy-a');
    await secureStore.writeString(
      AccountDataRegistry.legacyNotificationSecureKey,
      'legacy-a',
    );
    await secureStore.writeString('learning_state_v2.$namespaceA', 'private-a');
    await secureStore.writeString('learning_state_v2.$namespaceB', 'private-b');
    await preferences.save('notes_v1', 'legacy-a');
    await preferences.save('notes_v1.$namespaceA', 'private-a');
    await preferences.save('notes_v1.$namespaceB', 'private-b');
    await sensitivePreferences.save('memories_v1', 'legacy-a');
    await sensitivePreferences.save(
      'governed_memories_v2.$namespaceA',
      'private-a',
    );
    await sensitivePreferences.save(
      'governed_memories_v2.$namespaceB',
      'private-b',
    );
    await secureA.writeString('profile_entity_v1', 'generic-a');
    await secureB.writeString('profile_entity_v1', 'generic-b');
    await preferencesA.save('behavior_state_v1', 'generic-a');
    await preferencesB.save('behavior_state_v1', 'generic-b');
    await sensitiveA.save('timeline_events_v1', 'generic-a');
    await sensitiveB.save('timeline_events_v1', 'generic-b');

    final LocalUserDataCleanupService service = LocalUserDataCleanupService(
      hive: hive,
      secureStore: secureStore,
      preferences: preferences,
      sensitivePreferences: sensitivePreferences,
      notifications: NotificationScheduler(),
    );

    await service.clearForAccountSwitch('account-b');

    expect(hive.clearedBoxes, contains('tasks_box.$namespaceB'));
    expect(hive.clearedBoxes, isNot(contains('tasks_box')));
    expect(hive.clearedBoxes, isNot(contains('tasks_box.$namespaceA')));
    expect(await secureStore.readString('identity_id'), 'legacy-a');
    expect(
      await secureStore.readString(
        AccountDataRegistry.legacyNotificationSecureKey,
      ),
      'legacy-a',
    );
    expect(
      await secureStore.readString(AccountDataRegistry.accountBoundaryOwnerKey),
      'account-a',
    );
    expect(
      await secureStore.readString('learning_state_v2.$namespaceA'),
      'private-a',
    );
    expect(
      await secureStore.readString('learning_state_v2.$namespaceB'),
      isNull,
    );
    expect(preferences.load('notes_v1'), 'legacy-a');
    expect(preferences.load('notes_v1.$namespaceA'), 'private-a');
    expect(preferences.load('notes_v1.$namespaceB'), isNull);
    expect(sensitivePreferences.load('memories_v1'), 'legacy-a');
    expect(
      sensitivePreferences.load('governed_memories_v2.$namespaceA'),
      'private-a',
    );
    expect(
      sensitivePreferences.load('governed_memories_v2.$namespaceB'),
      isNull,
    );
    expect(await secureA.readString('profile_entity_v1'), 'generic-a');
    expect(await secureB.readString('profile_entity_v1'), isNull);
    expect(preferencesA.load('behavior_state_v1'), 'generic-a');
    expect(preferencesB.load('behavior_state_v1'), isNull);
    expect(sensitiveA.load('timeline_events_v1'), 'generic-a');
    expect(sensitiveB.load('timeline_events_v1'), isNull);
  });

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
    final SecureStore secureStore = SecureStore(
      backend: InMemorySecureStoreBackend(),
    );
    await secureStore.writeString(
      AccountDataRegistry.accountBoundaryOwnerKey,
      'account-a',
    );
    final LocalUserDataCleanupService service = LocalUserDataCleanupService(
      hive: _RecordingHiveStore(),
      secureStore: secureStore,
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

  test('detects and clears preserved sensitive corruption backups', () async {
    final _RecoverableMemoryPreferences sensitive =
        _RecoverableMemoryPreferences()..hasBackups = true;
    final SecureStore secureStore = SecureStore(
      backend: InMemorySecureStoreBackend(),
    );
    await secureStore.writeString(
      AccountDataRegistry.accountBoundaryOwnerKey,
      'account-a',
    );
    final LocalUserDataCleanupService service = LocalUserDataCleanupService(
      hive: const _DirectHiveStore(),
      secureStore: secureStore,
      preferences: _MemoryPreferences(),
      sensitivePreferences: sensitive,
      notifications: NotificationScheduler(),
    );

    expect(await service.hasUnownedAccountData(), isTrue);

    await service.clearForAccountSwitch('account-a');

    expect(sensitive.hasCorruptionBackups, isFalse);
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

class _RecoverableMemoryPreferences extends _MemoryPreferences
    implements CorruptionBackupStore {
  bool hasBackups = false;

  @override
  bool get hasCorruptionBackups => hasBackups;

  @override
  Future<void> clearCorruptionBackups() async {
    hasBackups = false;
  }
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
