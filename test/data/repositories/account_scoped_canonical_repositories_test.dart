import 'dart:io';

import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/repositories/decision_outcome_repository.dart';
import 'package:fantastic_guacamole/data/repositories/goal_repository.dart';
import 'package:fantastic_guacamole/data/repositories/habit_repository.dart';
import 'package:fantastic_guacamole/data/repositories/note_repository.dart';
import 'package:fantastic_guacamole/data/repositories/task_occurrence_repository.dart';
import 'package:fantastic_guacamole/data/repositories/task_repository.dart';
import 'package:fantastic_guacamole/data/storage/account_scoped_hive_storage.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDirectory;
  late _DirectHiveStore hive;
  late _MemoryPreferences preferences;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'account_scoped_canonical_repositories_test_',
    );
    await Hive.close();
    Hive.init(tempDirectory.path);
    hive = _DirectHiveStore();
    preferences = _MemoryPreferences();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'account A migration preserves legacy and account B stays empty',
    () async {
      final AccountStorageScope accountA = AccountStorageScope.authenticated(
        'account-a',
      );
      final AccountStorageScope accountB = AccountStorageScope.authenticated(
        'account-b',
      );
      final HiveStorage<String> legacyTasks = HiveStorage<String>(
        HiveBoxes.tasks,
        hive: hive,
      );
      final HiveStorage<String> legacyGoals = HiveStorage<String>(
        HiveBoxes.goals,
        hive: hive,
      );
      final HiveStorage<String> legacyHabits = HiveStorage<String>(
        HiveBoxes.habits,
        hive: hive,
      );
      await legacyTasks.open();
      await legacyGoals.open();
      await legacyHabits.open();
      await TaskRepository(storage: legacyTasks).saveTask(_task('legacy-task'));
      await GoalRepository(legacyGoals).saveGoal(_goal('legacy-goal'));
      await HabitRepository(
        legacyHabits,
      ).saveHabits(<HabitEntity>[_habit('legacy-habit')]);
      await preferences.save('notes_v1', '[${_noteJson('legacy-note')}]');

      final AccountScopedHiveStorage tasksA = _scopedStorage(
        HiveBoxes.tasks,
        accountA,
        hive,
        LegacyScopeOwnership.provenOwned,
      );
      final AccountScopedHiveStorage goalsA = _scopedStorage(
        HiveBoxes.goals,
        accountA,
        hive,
        LegacyScopeOwnership.provenOwned,
      );
      final AccountScopedHiveStorage habitsA = _scopedStorage(
        HiveBoxes.habits,
        accountA,
        hive,
        LegacyScopeOwnership.provenOwned,
      );
      final TaskRepository taskRepositoryA = TaskRepository(
        storage: tasksA,
        scope: accountA,
      );
      final GoalRepository goalRepositoryA = GoalRepository(
        goalsA,
        scope: accountA,
      );
      final HabitRepository habitRepositoryA = HabitRepository(
        habitsA,
        scope: accountA,
      );
      final NoteRepository noteRepositoryA = NoteRepository(
        preferences,
        scope: accountA,
        legacyOwnership: LegacyScopeOwnership.provenOwned,
      );

      expect((await taskRepositoryA.getAllTasks()).single.id, 'legacy-task');
      expect(goalRepositoryA.getGoals().single.id, 'legacy-goal');
      await goalsA.prepare();
      expect((await habitRepositoryA.getHabits()).single.id, 'legacy-habit');
      expect((await noteRepositoryA.getNotes()).single.id, 'legacy-note');

      final AccountScopedHiveStorage tasksB = _scopedStorage(
        HiveBoxes.tasks,
        accountB,
        hive,
        LegacyScopeOwnership.provenNotOwned,
      );
      final AccountScopedHiveStorage goalsB = _scopedStorage(
        HiveBoxes.goals,
        accountB,
        hive,
        LegacyScopeOwnership.provenNotOwned,
      );
      final AccountScopedHiveStorage habitsB = _scopedStorage(
        HiveBoxes.habits,
        accountB,
        hive,
        LegacyScopeOwnership.provenNotOwned,
      );
      final TaskRepository taskRepositoryB = TaskRepository(
        storage: tasksB,
        scope: accountB,
      );
      final GoalRepository goalRepositoryB = GoalRepository(
        goalsB,
        scope: accountB,
      );
      final HabitRepository habitRepositoryB = HabitRepository(
        habitsB,
        scope: accountB,
      );
      final NoteRepository noteRepositoryB = NoteRepository(
        preferences,
        scope: accountB,
        legacyOwnership: LegacyScopeOwnership.provenNotOwned,
      );

      expect(await taskRepositoryB.getAllTasks(), isEmpty);
      await goalsB.prepare();
      expect(goalRepositoryB.getGoals(), isEmpty);
      expect(await habitRepositoryB.getHabits(), isEmpty);
      expect(await noteRepositoryB.getNotes(), isEmpty);

      await taskRepositoryA.saveTask(_task('account-a-only'));
      await goalRepositoryA.saveGoal(_goal('account-a-only'));
      await habitRepositoryA.saveHabits(<HabitEntity>[
        _habit('account-a-only'),
      ]);
      await noteRepositoryA.saveNote(_note('account-a-only'));

      expect(await taskRepositoryB.getAllTasks(), isEmpty);
      expect(goalRepositoryB.getGoals(), isEmpty);
      expect(await habitRepositoryB.getHabits(), isEmpty);
      expect(await noteRepositoryB.getNotes(), isEmpty);
      expect(
        (await TaskRepository(storage: legacyTasks).getAllTasks()).single.id,
        'legacy-task',
      );
      expect(GoalRepository(legacyGoals).getGoals().single.id, 'legacy-goal');
      expect(
        (await HabitRepository(legacyHabits).getHabits()).single.id,
        'legacy-habit',
      );
      expect(preferences.load('notes_v1'), contains('legacy-note'));
    },
  );

  test(
    'signed-out writes fail closed across all canonical repositories',
    () async {
      const AccountStorageScope signedOut = AccountStorageScope.signedOut();
      final AccountScopedHiveStorage unavailable = _scopedStorage(
        HiveBoxes.tasks,
        signedOut,
        hive,
        LegacyScopeOwnership.unownedSignedOut,
      );

      await expectLater(
        TaskRepository(
          storage: unavailable,
          scope: signedOut,
        ).saveTask(_task('blocked-task')),
        throwsStateError,
      );
      await expectLater(
        () => GoalRepository(
          unavailable,
          scope: signedOut,
        ).saveGoal(_goal('blocked-goal')),
        throwsStateError,
      );
      await expectLater(
        () => HabitRepository(
          unavailable,
          scope: signedOut,
        ).saveHabits(<HabitEntity>[_habit('blocked-habit')]),
        throwsStateError,
      );
      await expectLater(
        NoteRepository(
          preferences,
          scope: signedOut,
        ).saveNote(_note('blocked-note')),
        throwsStateError,
      );
      await expectLater(
        TaskOccurrenceRepository.unavailable().save(
          const TaskOccurrence(
            taskId: 'blocked-task',
            seriesId: 'blocked-task',
            occurrenceKey: 'blocked-occurrence',
            initialScheduledFor: null,
          ),
        ),
        throwsStateError,
      );
      await expectLater(
        DecisionOutcomeRepository(preferences, signedOut).record(
          DecisionOutcomeEntity(
            decisionId: 'blocked-decision',
            kind: DecisionOutcomeKind.shown,
            surface: 'nexus',
            recordedAt: DateTime.utc(2026, 8, 30),
            modelVersion: 'local-v1',
            recommendationConfidence: 0.5,
          ),
        ),
        throwsStateError,
      );
    },
  );
}

AccountScopedHiveStorage _scopedStorage(
  String baseBox,
  AccountStorageScope scope,
  HiveStore hive,
  LegacyScopeOwnership ownership,
) => AccountScopedHiveStorage(
  baseBox: baseBox,
  scope: scope,
  hive: hive,
  legacyOwnership: ownership,
);

TaskEntity _task(String id) =>
    TaskEntity(id: id, title: 'Task $id', createdAt: DateTime.utc(2026, 8, 30));

GoalEntity _goal(String id) =>
    GoalEntity(id: id, title: 'Goal $id', createdAt: DateTime.utc(2026, 8, 30));

HabitEntity _habit(String id) => HabitEntity(
  id: id,
  title: 'Habit $id',
  createdAt: DateTime.utc(2026, 8, 30),
  updatedAt: DateTime.utc(2026, 8, 30, 1),
);

NoteEntity _note(String id) =>
    NoteEntity(id: id, title: 'Note $id', createdAt: DateTime.utc(2026, 8, 30));

String _noteJson(String id) =>
    '{"id":"$id","title":"Note $id",'
    '"createdAt":"2026-08-30T00:00:00.000Z",'
    '"updatedAt":"2026-08-30T00:00:00.000Z",'
    '"isArchived":false}';

class _MemoryPreferences implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> init() async {}

  @override
  Future<void> save(String key, String value) async => values[key] = value;

  @override
  String? load(String key) => values[key];

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> clear() async => values.clear();
}

class _DirectHiveStore implements HiveStore {
  @override
  Future<void> init() async {}

  @override
  bool isBoxOpen(String key) => Hive.isBoxOpen(key);

  @override
  Future<Box<T>> openBox<T>(String key) async {
    if (Hive.isBoxOpen(key)) return Hive.box<T>(key);
    return Hive.openBox<T>(key);
  }

  @override
  Box<T> box<T>(String key) => Hive.box<T>(key);

  @override
  Future<void> clearBox(String key) async {
    final Box<dynamic> box = Hive.isBoxOpen(key)
        ? Hive.box<dynamic>(key)
        : await Hive.openBox<dynamic>(key);
    await box.clear();
  }

  @override
  Future<void> closeBox(String key) async {
    if (Hive.isBoxOpen(key)) await Hive.box<dynamic>(key).close();
  }
}
