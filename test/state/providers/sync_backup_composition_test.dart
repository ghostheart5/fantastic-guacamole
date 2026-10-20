import 'dart:io';
import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/services/backup_service.dart';
import 'package:fantastic_guacamole/data/services/backup_cipher.dart';
import 'package:fantastic_guacamole/data/services/sync_service.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_scoped_store_provider.dart';
import 'package:fantastic_guacamole/state/providers/decision_outcome_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The production SyncService and BackupService composition is never overridden.
// Only platform storage and the unavailable network client are isolated here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    directory = await Directory.systemTemp.createTemp(
      'sync_backup_composition_',
    );
    Hive.init(directory.path);
    container = ProviderContainer(
      overrides: [
        hiveStoreProvider.overrideWithValue(_DirectHiveStore()),
        sharedPrefsStoreProvider.overrideWithValue(_Preferences(preferences)),
        sensitivePrefsStoreProvider.overrideWithValue(
          _Preferences(preferences),
        ),
        secureStoreProvider.overrideWithValue(
          SecureStore(backend: InMemorySecureStoreBackend()),
        ),
        supabaseClientProvider.overrideWithValue(null),
        accountStorageScopeProvider.overrideWith((ref) => ref.watch(_scope)),
        accountLegacyOwnershipProvider.overrideWithValue(
          LegacyScopeOwnership.provenNotOwned,
        ),
        cloudBackupPreferencesProvider.overrideWith(
          (ref) async => SharedPrefsStorage(preferences),
        ),
      ],
    );
    await container.read(cloudBackupPreferencesProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await Hive.close().timeout(const Duration(seconds: 5));
    final absolute = directory.absolute.path;
    expect(absolute.startsWith(Directory.systemTemp.absolute.path), isTrue);
    expect(
      directory.path.split(Platform.pathSeparator).last,
      startsWith('sync_backup_composition_'),
    );
    await directory.delete(recursive: true).timeout(const Duration(seconds: 5));
  });

  test(
    'production sync backup composition includes every canonical domain',
    () async {
      await _seed(container, 'a');
      final backup = container.read(syncServiceProvider)!.backup;
      // Before the repair this exact production composition throws for missing
      // domain repositories, even though each canonical provider is available.
      final payload = await backup.createFullBackup();
      _expectCanonicalBindings(container, backup);
      expect(payload['version'], '5.0.0');
      for (final field in _domains) {
        expect(payload[field], hasLength(1), reason: field);
      }
      expect(
        ((payload['tasks'] as List<dynamic>).single
            as Map<String, dynamic>)['isCompleted'],
        isTrue,
      );
      expect(
        ((payload['taskOccurrences'] as List<dynamic>).single
            as Map<String, dynamic>)['transitions'],
        hasLength(1),
      );
      expect(
        ((payload['notes'] as List<dynamic>).single
            as Map<String, dynamic>)['taskId'],
        'task-a',
      );
      backup.validateFullBackup(payload);
      // Canonical composition does not authorize widening the cloud payload.
      // SyncService uses this versioned path, rather than the portable v5 one.
      final cloud = (await backup.createVersionedFullBackup()).payload;
      expect(cloud['version'], '4.0.0');
      final manifest = cloud['manifest'] as Map<String, dynamic>;
      expect(manifest['backupKind'], 'containedCloudLegacy');
      expect(
        manifest['includedDomains'],
        unorderedEquals(['tasks', 'profile', 'settings']),
      );
      expect(manifest['cloudCapabilityContained'], isTrue);
      for (final field in _domains.where((field) => field != 'tasks')) {
        expect(cloud.containsKey(field), isFalse, reason: field);
        final manifestId =
            const {
              'taskOccurrences': 'task_occurrences',
              'habitOccurrences': 'habit_occurrences',
              'decisionOutcomes': 'decision_outcomes',
            }[field] ??
            field;
        expect(manifest['excludedDomains'], contains(manifestId));
      }
    },
  );

  SyncService planningService(_PlanningGateway gateway) => SyncService(
    backup: container.read(syncServiceProvider)!.backup,
    gateway: gateway,
    secureStore: container.read(secureStoreProvider),
    expectedAccountId: 'owner-a',
    currentAccountId: () =>
        container.read(accountStorageScopeProvider).rawUserId,
    syncEnabled: true,
    restoreEnabled: true,
  );

  test(
    'confirmed encrypted snapshot restores every planning domain and Timeline',
    () async {
      await _seed(container, 'a');
      final gateway = _PlanningGateway();
      final service = planningService(gateway);
      final before = (await service.backup.createPlanningCloudBackup()).payload;
      expect(await service.backupPlanningToCloud(), CloudSyncOutcome.synced);
      expect(gateway.reads, 2, reason: 'success requires encrypted readback');
      expect(gateway.payload!.containsKey('notes'), isFalse);
      final decrypted = await BackupCipher(
        container.read(secureStoreProvider),
        accountId: 'owner-a',
      ).decryptPayload(gateway.payload!);
      expect(decrypted['version'], '6.0.0');
      for (final field in [..._domains, 'timelineEvents']) {
        expect(decrypted[field], before[field], reason: field);
      }
      await container.read(domainTaskRepositoryProvider).deleteTask('task-a');
      await container.read(domainGoalRepositoryProvider).saveGoals([]);
      await container.read(domainHabitRepositoryProvider).saveHabits([]);
      await container.read(domainNoteRepositoryProvider).deleteNote('note-a');
      await container
          .read(taskOccurrenceRepositoryProvider)
          .replaceSnapshot([]);
      await container
          .read(habitOccurrenceRepositoryProvider)!
          .replaceSnapshot([]);
      await container
          .read(decisionOutcomeRepositoryProvider)!
          .replaceSnapshot([]);
      await container.read(domainTimelineRepositoryProvider).saveEvents([]);
      expect(await service.restoreFromCloud(), CloudRestoreOutcome.restored);
      final restored =
          (await service.backup.createPlanningCloudBackup()).payload;
      for (final field in [
        ..._domains,
        'timelineEvents',
        'recordCounts',
        'account',
      ]) {
        expect(restored[field], before[field], reason: field);
      }
      expect(
        container
            .read(domainTimelineRepositoryProvider)
            .getEvents()
            .single
            .dateOnly,
        isTrue,
      );
    },
  );

  test(
    'explicit replacement preserves deletions and legacy sync cannot downgrade it',
    () async {
      await _seed(container, 'a');
      final gateway = _PlanningGateway();
      final service = planningService(gateway);
      expect(await service.backupPlanningToCloud(), CloudSyncOutcome.synced);
      await container.read(domainNoteRepositoryProvider).deleteNote('note-a');
      expect(await service.backupPlanningToCloud(), CloudSyncOutcome.synced);
      final uploaded = jsonEncode(gateway.payload);
      final revision = gateway.revision;
      expect(await service.syncDeltaOutcome(), CloudSyncOutcome.conflict);
      expect(jsonEncode(gateway.payload), uploaded);
      expect(gateway.revision, revision);
      expect(await service.restoreFromCloud(), CloudRestoreOutcome.restored);
      expect(
        await container.read(domainNoteRepositoryProvider).getNotes(),
        isEmpty,
      );
    },
  );

  test(
    'account switch and withdrawn transfer permission prevent upload',
    () async {
      await _seed(container, 'a');
      var allowed = true;
      final gateway = _PlanningGateway()..onRead = () => allowed = false;
      expect(
        await planningService(
          gateway,
        ).backupPlanningToCloud(shouldContinue: () => allowed),
        CloudSyncOutcome.disabled,
      );
      expect(gateway.writes, 0);
      gateway.onRead = () => container
          .read(_scope.notifier)
          .set(AccountStorageScope.authenticated('owner-b'));
      expect(
        await planningService(gateway).backupPlanningToCloud(),
        CloudSyncOutcome.accountChanged,
      );
      expect(gateway.writes, 0);
    },
  );

  test(
    'full planning restore rejects another account before changing its records',
    () async {
      await _seed(container, 'a');
      final source =
          (await container
                  .read(syncServiceProvider)!
                  .backup
                  .createPlanningCloudBackup())
              .payload;
      container
          .read(_scope.notifier)
          .set(AccountStorageScope.authenticated('owner-b'));
      await container.read(domainGoalRepositoryProvider).saveGoals([]);
      final other = container.read(syncServiceProvider)!.backup;
      await expectLater(
        other.restoreFullBackup(source),
        throwsA(isA<FormatException>()),
      );
      expect(await other.taskRepository.getAllTasks(), isEmpty);
      expect(other.timelineRepository!.getEvents(), isEmpty);
      expect(await other.noteRepository!.getNotes(), isEmpty);
    },
  );

  test(
    'full restore rolls back canonical records when Timeline persistence fails',
    () async {
      await _seed(container, 'a');
      final normal = container.read(syncServiceProvider)!.backup;
      final before = (await normal.createPlanningCloudBackup()).payload;
      final incoming = jsonDecode(jsonEncode(before)) as Map<String, dynamic>;
      ((incoming['tasks'] as List<dynamic>).single
              as Map<String, dynamic>)['title'] =
          'Incoming task';
      ((incoming['timelineEvents'] as List<dynamic>).single
              as Map<String, dynamic>)['title'] =
          'Incoming history';
      final failing = BackupService(
        taskRepository: normal.taskRepository,
        profileStorage: normal.profileStorage,
        prefs: normal.prefs,
        scope: normal.scope,
        goalRepository: normal.goalRepository,
        habitRepository: normal.habitRepository,
        noteRepository: normal.noteRepository,
        taskOccurrenceRepository: normal.taskOccurrenceRepository,
        habitOccurrenceRepository: normal.habitOccurrenceRepository,
        decisionOutcomeRepository: normal.decisionOutcomeRepository,
        secureProfileStore: normal.secureProfileStore,
        timelineRepository: _FailOnceTimeline(normal.timelineRepository!),
      );
      await expectLater(
        failing.restoreFullBackup(incoming),
        throwsA(isA<StateError>()),
      );
      final after = (await normal.createPlanningCloudBackup()).payload;
      for (final field in [
        ..._domains,
        'timelineEvents',
        'profile',
        'settings',
      ]) {
        expect(after[field], before[field], reason: field);
      }
    },
  );

  test(
    'full planning snapshot fails closed on malformed history and CAS conflicts',
    () async {
      await _seed(container, 'a');
      final service = planningService(_PlanningGateway()..conflict = true);
      expect(await service.backupPlanningToCloud(), CloudSyncOutcome.conflict);
      final invalid =
          (await service.backup.createPlanningCloudBackup()).payload;
      ((invalid['timelineEvents'] as List<dynamic>).single
              as Map<String, dynamic>)['status'] =
          'invented';
      await expectLater(
        service.backup.restoreFullBackup(invalid),
        throwsA(isA<FormatException>()),
      );
      expect(
        container
            .read(domainTimelineRepositoryProvider)
            .getEvents()
            .single
            .title,
        'History a',
      );
    },
  );

  test(
    'a Timeline edit during download prevents uploading a stale snapshot',
    () async {
      await _seed(container, 'a');
      final gateway = _PlanningGateway()
        ..beforeRead = () =>
            container.read(domainTimelineRepositoryProvider).saveEvents([]);
      expect(
        await planningService(gateway).backupPlanningToCloud(),
        CloudSyncOutcome.conflict,
      );
      expect(gateway.writes, 0);
      expect(
        container.read(domainTimelineRepositoryProvider).getEvents(),
        isEmpty,
      );
    },
  );

  Future<void> mutatePlanningDomain(String domain) async {
    switch (domain) {
      case 'goals':
        await container.read(domainGoalRepositoryProvider).deleteGoal('goal-a');
      case 'task occurrences':
        await container
            .read(taskOccurrenceRepositoryProvider)
            .replaceSnapshot([]);
      case 'rhythm occurrences':
        await container
            .read(habitOccurrenceRepositoryProvider)!
            .replaceSnapshot([]);
      case 'decision outcomes':
        await container.read(decisionOutcomeRepositoryProvider)!.clear();
      case 'rhythms':
        await container.read(domainHabitRepositoryProvider).saveHabits([]);
      case 'notes':
        await container.read(domainNoteRepositoryProvider).deleteNote('note-a');
      case 'reminder settings':
        await container
            .read(accountSharedPrefsStoreProvider)
            .save('goal_reminders_enabled', 'false');
      case 'typed settings':
        await container
            .read(syncServiceProvider)!
            .backup
            .prefs
            .setString('daily_planning_reminder_time', '19:30');
    }
  }

  for (final domain in [
    'goals',
    'task occurrences',
    'rhythm occurrences',
    'decision outcomes',
    'rhythms',
    'notes',
    'reminder settings',
    'typed settings',
  ]) {
    for (final readNumber in [1, 2]) {
      test(
        'a $domain mutation during read $readNumber rejects stale backup success',
        () async {
          await _seed(container, 'a');
          var reads = 0;
          final gateway = _PlanningGateway()
            ..beforeRead = () async {
              if (++reads == readNumber) await mutatePlanningDomain(domain);
            };
          expect(
            await planningService(gateway).backupPlanningToCloud(),
            CloudSyncOutcome.conflict,
          );
          expect(gateway.writes, readNumber == 1 ? 0 : 1);
        },
      );
    }
  }

  test(
    'corrupt local history cannot replace a verified cloud snapshot',
    () async {
      await _seed(container, 'a');
      final gateway = _PlanningGateway();
      final service = planningService(gateway);
      expect(await service.backupPlanningToCloud(), CloudSyncOutcome.synced);
      final previous = jsonEncode(gateway.payload);
      final key = container
          .read(accountStorageScopeProvider)
          .namespace!
          .scopedKey('timeline_events_v1');
      await container
          .read(sensitivePrefsStoreProvider)
          .save(key, 'unreadable fixture');
      await expectLater(
        service.backupPlanningToCloud(),
        throwsA(isA<FormatException>()),
      );
      expect(jsonEncode(gateway.payload), previous);
      expect(
        container.read(sensitivePrefsStoreProvider).load(key),
        'unreadable fixture',
      );
    },
  );

  test(
    'upload success requires a matching verified encrypted readback',
    () async {
      await _seed(container, 'a');
      final gateway = _PlanningGateway()..corruptReadback = true;
      expect(
        await planningService(gateway).backupPlanningToCloud(),
        CloudSyncOutcome.uploadFailed,
      );
      expect(gateway.writes, 1);
      expect(
        await container.read(domainNoteRepositoryProvider).getNotes(),
        hasLength(1),
      );
    },
  );

  test(
    'production composed backup restores canonical records and terminal history',
    () async {
      await _seed(container, 'a');
      final backup = container.read(syncServiceProvider)!.backup;
      final before = await backup.createFullBackup();
      await container.read(domainTaskRepositoryProvider).deleteTask('task-a');
      await container.read(domainGoalRepositoryProvider).saveGoals([]);
      await container.read(domainHabitRepositoryProvider).saveHabits([]);
      await container.read(domainNoteRepositoryProvider).deleteNote('note-a');
      await container
          .read(taskOccurrenceRepositoryProvider)
          .replaceSnapshot([]);
      await container
          .read(habitOccurrenceRepositoryProvider)!
          .replaceSnapshot([]);
      await container
          .read(decisionOutcomeRepositoryProvider)!
          .replaceSnapshot([]);
      await backup.restoreFullBackup(before);
      final after = await backup.createFullBackup();
      for (final field in [
        ..._domains,
        'profile',
        'settings',
        'account',
        'recordCounts',
      ]) {
        expect(after[field], before[field], reason: field);
      }
      expect(
        (await container
                .read(domainTaskRepositoryProvider)
                .getTaskById('task-a'))!
            .isCompleted,
        isTrue,
      );
    },
  );

  test(
    'account switch rebuilds canonical composition and rejects other-account restore',
    () async {
      await _seed(container, 'a');
      final serviceA = container.read(syncServiceProvider)!;
      final payloadA = await serviceA.backup.createFullBackup();
      container
          .read(_scope.notifier)
          .set(AccountStorageScope.authenticated('owner-b'));
      await container.read(domainGoalRepositoryProvider).saveGoals([]);
      final serviceB = container.read(syncServiceProvider)!;
      expect(identical(serviceA, serviceB), isFalse);
      _expectCanonicalBindings(container, serviceB.backup);
      final beforeB = await serviceB.backup.createFullBackup();
      for (final field in _domains) {
        expect(beforeB[field], isEmpty, reason: field);
      }
      await expectLater(
        serviceB.backup.restoreFullBackup(payloadA),
        throwsA(isA<FormatException>()),
      );
      final afterB = await serviceB.backup.createFullBackup();
      for (final field in [
        ..._domains,
        'profile',
        'settings',
        'account',
        'recordCounts',
      ]) {
        expect(afterB[field], beforeB[field], reason: field);
      }
      container
          .read(_scope.notifier)
          .set(AccountStorageScope.authenticated('owner-a'));
      final returned = await container
          .read(syncServiceProvider)!
          .backup
          .createFullBackup();
      for (final field in _domains) {
        expect(returned[field], payloadA[field], reason: field);
      }
    },
  );

  test(
    'signed-out production composition refuses backup before domain reads',
    () async {
      await _seed(container, 'a');
      container
          .read(_scope.notifier)
          .set(const AccountStorageScope.signedOut());
      final backup = container.read(syncServiceProvider)!.backup;
      await expectLater(backup.createFullBackup(), throwsA(isA<StateError>()));
    },
  );
}

const _domains = [
  'tasks',
  'goals',
  'habits',
  'notes',
  'taskOccurrences',
  'habitOccurrences',
  'decisionOutcomes',
];

void _expectCanonicalBindings(
  ProviderContainer container,
  BackupService backup,
) {
  expect(
    identical(
      backup.taskRepository,
      container.read(domainTaskRepositoryProvider),
    ),
    isTrue,
  );
  expect(
    identical(
      backup.goalRepository,
      container.read(domainGoalRepositoryProvider),
    ),
    isTrue,
  );
  expect(
    identical(
      backup.habitRepository,
      container.read(domainHabitRepositoryProvider),
    ),
    isTrue,
  );
  expect(
    identical(
      backup.noteRepository,
      container.read(domainNoteRepositoryProvider),
    ),
    isTrue,
  );
  expect(
    identical(
      backup.taskOccurrenceRepository,
      container.read(taskOccurrenceRepositoryProvider),
    ),
    isTrue,
  );
  expect(
    identical(
      backup.habitOccurrenceRepository,
      container.read(habitOccurrenceRepositoryProvider),
    ),
    isTrue,
  );
  expect(
    identical(
      backup.decisionOutcomeRepository,
      container.read(decisionOutcomeRepositoryProvider),
    ),
    isTrue,
  );
}

Future<void> _seed(ProviderContainer container, String suffix) async {
  final at = DateTime.utc(2026, 10, 14, 12);
  final account = container.read(accountStorageScopeProvider).rawUserId;
  await container.read(domainTimelineRepositoryProvider).saveEvents([
    TimelineEventEntity(
      id: 'event-$suffix',
      type: TimelineEventType.task,
      title: 'History $suffix',
      detail: 'Saved history',
      timestamp: at,
      dueAt: at,
      dateOnly: true,
    ),
  ]);
  final task = TaskEntity(
    id: 'task-$suffix',
    title: 'Completed task $suffix',
    createdAt: at,
    updatedAt: at,
    isCompleted: true,
    completedAt: at,
  );
  await container.read(domainTaskRepositoryProvider).saveTask(task);
  await container
      .read(domainGoalRepositoryProvider)
      .saveGoal(
        GoalEntity(id: 'goal-$suffix', title: 'Goal $suffix', createdAt: at),
      );
  final habit = HabitEntity(
    id: 'habit-$suffix',
    title: 'Habit $suffix',
    createdAt: at,
    userId: account,
  );
  await container.read(domainHabitRepositoryProvider).saveHabits([habit]);
  await container
      .read(domainNoteRepositoryProvider)
      .saveNote(
        NoteEntity(
          id: 'note-$suffix',
          title: 'Note $suffix',
          body: 'Owned detail',
          createdAt: at,
          userId: account,
          taskId: task.id,
        ),
      );
  await container
      .read(taskOccurrenceRepositoryProvider)
      .save(
        TaskOccurrence(
          taskId: task.id,
          seriesId: TaskOccurrence.seriesIdFor(task),
          occurrenceKey: TaskOccurrence.occurrenceKeyFor(task),
          initialScheduledFor: null,
          transitions: [
            TaskOccurrenceTransition(
              operationId: 'task-op-$suffix',
              outcome: TaskOccurrenceOutcome.completed,
              at: at,
            ),
          ],
        ),
      );
  await container
      .read(habitOccurrenceRepositoryProvider)!
      .save(
        HabitOccurrenceEntity(
          habitId: habit.id,
          occurrenceKey: RhythmPlanningContext.occurrenceKey(habit, at),
          operationId: 'habit-op-$suffix',
          outcome: HabitOccurrenceOutcome.completed,
          recordedAt: at,
        ),
      );
  await container
      .read(decisionOutcomeRepositoryProvider)!
      .record(
        DecisionOutcomeEntity(
          decisionId: 'decision-$suffix',
          kind: DecisionOutcomeKind.completed,
          surface: 'test-fixture',
          recordedAt: at,
          modelVersion: 'composition-fixture-v1',
          recommendationConfidence: 1,
          subjectId: task.id,
        ),
      );
}

final _scope = NotifierProvider<_Scope, AccountStorageScope>(_Scope.new);

class _PlanningGateway implements CloudBackupGateway {
  Map<String, dynamic>? payload;
  int revision = 0;
  int writes = 0;
  int reads = 0;
  bool conflict = false;
  bool corruptReadback = false;
  Future<void> Function()? beforeRead;
  void Function()? onRead;
  @override
  Future<CloudBackupReadResult> downloadBackup() async {
    reads++;
    await beforeRead?.call();
    onRead?.call();
    if (corruptReadback && reads > 1) {
      return const CloudBackupReadResult.malformed();
    }
    return payload == null
        ? const CloudBackupReadResult.notFound()
        : CloudBackupReadResult.found(payload, revision: revision);
  }

  @override
  Future<CloudBackupWriteResult> compareAndSwapBackup(
    Map<String, dynamic> backup, {
    required int expectedRevision,
  }) async {
    if (conflict || expectedRevision != revision) {
      return CloudBackupWriteResult.conflict(revision);
    }
    writes++;
    payload = backup;
    return CloudBackupWriteResult.written(++revision);
  }

  @override
  Future<bool> uploadBackup(Map<String, dynamic> backup) async => false;
  @override
  Future<bool> uploadTasks(Map<String, dynamic> backup) async => false;
  @override
  Future<CloudBackupReadResult> downloadTasks() async =>
      const CloudBackupReadResult.notFound();
}

class _FailOnceTimeline implements ITimelineRepository {
  _FailOnceTimeline(this.delegate);
  final ITimelineRepository delegate;
  bool fail = true;
  @override
  bool get lastReadCorrupted => delegate.lastReadCorrupted;
  @override
  List<TimelineEventEntity> getEvents() => delegate.getEvents();
  @override
  Future<void> saveEvents(List<TimelineEventEntity> events) async {
    await delegate.saveEvents(events);
    if (fail) {
      fail = false;
      throw StateError('Timeline fixture write failure');
    }
  }

  @override
  Future<void> addEvent(TimelineEventEntity event) => delegate.addEvent(event);
  @override
  Future<void> removeEvent(String id) => delegate.removeEvent(id);
}

class _Scope extends Notifier<AccountStorageScope> {
  @override
  AccountStorageScope build() => AccountStorageScope.authenticated('owner-a');
  void set(AccountStorageScope value) => state = value;
}

class _Preferences implements SharedPrefsStore, EnumerableSharedPrefsStore {
  _Preferences(this.preferences);
  final SharedPreferences preferences;
  @override
  Future<void> init() async {}
  @override
  Future<void> save(String key, String value) async {
    await preferences.setString(key, value);
  }

  @override
  String? load(String key) => preferences.getString(key);
  @override
  Future<void> delete(String key) async {
    await preferences.remove(key);
  }

  @override
  Future<void> clear() async {
    await preferences.clear();
  }

  @override
  Future<Set<String>> keys() async => preferences.getKeys();
}

class _DirectHiveStore implements HiveStore {
  @override
  Future<void> init() async {}
  @override
  bool isBoxOpen(String key) => Hive.isBoxOpen(key);
  @override
  Future<Box<T>> openBox<T>(String key) async =>
      Hive.isBoxOpen(key) ? Hive.box<T>(key) : await Hive.openBox<T>(key);
  @override
  Box<T> box<T>(String key) => Hive.box<T>(key);
  @override
  Future<void> clearBox(String key) async {
    await (await openBox<String>(key)).clear();
  }

  @override
  Future<void> closeBox(String key) async {
    if (Hive.isBoxOpen(key)) await Hive.box<String>(key).close();
  }
}
