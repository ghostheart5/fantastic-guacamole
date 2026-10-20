import 'dart:io';

import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/services/backup_service.dart';
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
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
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
