import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fantastic_guacamole/core/async/account_storage_mutation.dart';
import 'package:fantastic_guacamole/core/async/keyed_mutation_coordinator.dart';
import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
import 'package:fantastic_guacamole/data/repositories/decision_outcome_repository.dart';
import 'package:fantastic_guacamole/data/repositories/habit_occurrence_repository.dart';
import 'package:fantastic_guacamole/data/repositories/note_repository.dart';
import 'package:fantastic_guacamole/data/repositories/task_occurrence_repository.dart';
import 'package:fantastic_guacamole/data/services/backup_service.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_decision_outcome_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_note_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late _MemoryTaskRepository repository;
  late BackupService service;
  late Directory hiveDirectory;
  late HiveStorage<String> profileStorage;
  late HiveStorage<String> occurrenceStorage;
  late _MemoryGoalRepository goalRepository;
  late _MemoryHabitRepository habitRepository;
  late _MemoryNoteRepository noteRepository;
  late TaskOccurrenceRepository occurrenceRepository;
  late _MemoryPrefsStore habitOccurrenceStore;
  late HabitOccurrenceRepository habitOccurrenceRepository;
  late _MemoryDecisionOutcomeRepository decisionOutcomeRepository;
  final AccountStorageScope backupScope = AccountStorageScope.authenticated(
    'account-a',
  );

  BackupService buildService({
    required ITaskRepository taskRepository,
    required HiveStorage<String> profileStorage,
    required SharedPrefsStorage prefs,
    SecureStore? secureProfileStore,
    KeyedMutationCoordinator? mutationCoordinator,
  }) => BackupService(
    taskRepository: taskRepository,
    profileStorage: profileStorage,
    prefs: prefs,
    scope: backupScope,
    goalRepository: goalRepository,
    habitRepository: habitRepository,
    noteRepository: noteRepository,
    taskOccurrenceRepository: occurrenceRepository,
    habitOccurrenceRepository: habitOccurrenceRepository,
    decisionOutcomeRepository: decisionOutcomeRepository,
    secureProfileStore: secureProfileStore,
    mutationCoordinator: mutationCoordinator,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    hiveDirectory = await Directory.systemTemp.createTemp(
      'chronospark_backup_test_',
    );
    Hive.init(hiveDirectory.path);
    repository = _MemoryTaskRepository();
    profileStorage = HiveStorage<String>('profile_box', hive: _TestHiveStore());
    occurrenceStorage = HiveStorage<String>(
      'task_occurrences_test',
      hive: _TestHiveStore(),
    );
    goalRepository = _MemoryGoalRepository();
    habitRepository = _MemoryHabitRepository();
    noteRepository = _MemoryNoteRepository();
    occurrenceRepository = TaskOccurrenceRepository(occurrenceStorage);
    habitOccurrenceStore = _MemoryPrefsStore();
    habitOccurrenceRepository = HabitOccurrenceRepository(
      habitOccurrenceStore,
      backupScope,
    );
    decisionOutcomeRepository = _MemoryDecisionOutcomeRepository();
    service = buildService(
      taskRepository: repository,
      profileStorage: profileStorage,
      prefs: SharedPrefsStorage(await SharedPreferences.getInstance()),
    );
  });

  tearDown(() async {
    await profileStorage.close();
    await occurrenceStorage.close();
    await Hive.close();
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  test('backup exceptions expose stable diagnostic messages', () {
    expect(
      const BackupRestoreRollbackException(
        restoreErrorType: 'StateError',
        rollbackErrorType: 'FormatException',
      ).toString(),
      'Backup restore failed and rollback could not complete '
      '(restore: StateError, rollback: FormatException).',
    );
    expect(
      const BackupRestoreCancelledException().toString(),
      'Backup restore was cancelled before commit.',
    );
    expect(
      const BackupConcurrentMutationException().toString(),
      'Account data changed while backup work was in flight.',
    );
  });

  test('full backup waits for an in-flight account storage write', () async {
    final KeyedMutationCoordinator coordinator = KeyedMutationCoordinator();
    final Completer<void> started = Completer<void>();
    final Completer<void> release = Completer<void>();
    final BackupService coordinated = buildService(
      taskRepository: repository,
      profileStorage: profileStorage,
      prefs: service.prefs,
      mutationCoordinator: coordinator,
    );
    final Future<void> mutation = runAccountStorageMutation(() async {
      started.complete();
      await release.future;
      await repository.saveTask(
        TaskEntity(
          id: 'committed-task',
          title: 'Committed together',
          createdAt: DateTime.utc(2026, 9, 5),
        ),
      );
      await profileStorage.put('profile_state', '{"name":"Committed profile"}');
    }, coordinator: coordinator);
    await started.future;
    final Future<Map<String, dynamic>> backup = coordinated.createFullBackup();
    await Future<void>.delayed(Duration.zero);
    final int readsWhileWritePending = repository.readCount;
    release.complete();
    await mutation;
    final Map<String, dynamic> result = await backup;
    expect(readsWhileWritePending, 0);
    final Map<String, dynamic> savedTask =
        (result['tasks'] as List<dynamic>).single as Map<String, dynamic>;
    expect(savedTask['id'], 'committed-task');
    expect(result['profile'], <String, dynamic>{'name': 'Committed profile'});
  });

  for (final String invalidProfile in <String>[
    '{private-corrupt',
    '',
    'null',
    '[]',
    '42',
  ]) {
    test(
      'backup rejects invalid stored profile ${invalidProfile.length}',
      () async {
        await profileStorage.put('profile_state', invalidProfile);
        await expectLater(
          service.createFullBackup(),
          throwsA(
            isA<FormatException>().having(
              (FormatException error) => error.message,
              'safe message',
              'Stored profile is invalid; backup cancelled.',
            ),
          ),
        );
        expect(profileStorage.get('profile_state'), invalidProfile);
        await expectLater(
          service.createVersionedFullBackup(),
          throwsFormatException,
        );
        await expectLater(service.backupProfile(), throwsFormatException);
        expect(profileStorage.get('profile_state'), invalidProfile);
      },
    );
  }

  test('backs up canonical task fields', () async {
    final DateTime createdAt = DateTime.utc(2026, 7, 4, 12);
    final DateTime dueDate = DateTime.utc(2026, 7, 8);
    await repository.saveTask(
      TaskEntity(
        id: 'task-1',
        title: 'Canonical task',
        description: 'Full domain record',
        createdAt: createdAt,
        priority: 5,
        difficulty: 4,
        energyRequired: 2,
        estimatedDuration: const Duration(minutes: 45),
        dueDate: dueDate,
        goalId: 'goal-1',
        subtasks: const <String>['Draft', 'Review'],
        recurrenceRule: RecurrenceRule.weekly,
      ),
    );

    final Map<String, dynamic> backup = await service.backupTasks();
    final Map<String, dynamic> task =
        (backup['tasks'] as List<dynamic>).single as Map<String, dynamic>;

    expect(task['id'], 'task-1');
    expect(task['priority'], 5);
    expect(task['estimatedDurationMs'], 2700000);
    expect(task['dueDate'], dueDate.toIso8601String());
    expect(task['goalId'], 'goal-1');
    expect(task['recurrenceRule'], 'weekly');
  });

  test('restore replaces repository records with canonical entities', () async {
    await repository.saveTask(
      TaskEntity(id: 'old', title: 'Remove me', createdAt: DateTime.utc(2025)),
    );

    await service.restoreTasks(<String, dynamic>{
      'tasks': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'restored',
          'title': 'Restored task',
          'createdAt': '2026-07-04T12:00:00.000Z',
          'isCompleted': true,
          'priority': 4,
          'difficulty': 2,
          'energyRequired': 3,
          'completedAt': '2026-07-04T13:00:00.000Z',
          'subtasks': <String>['One'],
          'recurrenceRule': 'daily',
        },
      ],
    });

    expect(await repository.getTaskById('old'), isNull);
    final TaskEntity? restored = await repository.getTaskById('restored');
    expect(restored, isNotNull);
    expect(restored!.isCompleted, isTrue);
    expect(restored.priority, 4);
    expect(restored.recurrenceRule, RecurrenceRule.daily);
  });

  test('an empty task backup clears canonical tasks', () async {
    await repository.saveTask(
      TaskEntity(id: 'old', title: 'Remove me', createdAt: DateTime.utc(2025)),
    );

    await service.restoreTasks(<String, dynamic>{'tasks': <dynamic>[]});

    expect(await repository.getAllTasks(), isEmpty);
  });

  test('createFullBackup includes tasks profile and settings', () async {
    await repository.saveTask(
      TaskEntity(
        id: 'task-1',
        title: 'Ship audit',
        createdAt: DateTime.utc(2026, 7, 5),
      ),
    );
    await profileStorage.put(
      'profile_state',
      jsonEncode(<String, dynamic>{'name': 'Keegan', 'xp': 42}),
    );
    await service.prefs.setString(
      'user_preferences_json',
      jsonEncode(<String, dynamic>{'planningStyle': 'quiet'}),
    );
    await service.prefs.setBool('cloud_sync_enabled_v1', true);
    await service.prefs.setString('reflection_reminder_enabled', 'true');
    await service.prefs.setString('app_theme_entity_v1', 'device-theme');
    await service.prefs.setJson('settings', <String, dynamic>{
      'obsolete': true,
    });

    final Map<String, dynamic> backup = await service.createFullBackup();
    final Map<String, dynamic> task =
        ((backup['tasks'] as List<dynamic>).single as Map<dynamic, dynamic>)
            .map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            );

    expect(backup['version'], '5.0.0');
    expect(backup['manifest'], isA<Map<String, dynamic>>());
    expect(
      ((backup['manifest'] as Map<String, dynamic>)['includedDomains']
              as List<dynamic>)
          .cast<String>(),
      containsAll(<String>[
        'tasks',
        'goals',
        'habits',
        'notes',
        'task_occurrences',
        'habit_occurrences',
        'decision_outcomes',
        'profile',
        'settings',
      ]),
    );
    expect(
      ((backup['manifest'] as Map<String, dynamic>)['excludedDomains']
              as List<dynamic>)
          .cast<String>(),
      contains('timeline'),
    );
    expect(task['id'], 'task-1');
    expect(backup['profile'], <String, dynamic>{'name': 'Keegan', 'xp': 42});
    expect(backup['settings'], <String, dynamic>{
      'cloud_sync_enabled_v1': true,
      'reflection_reminder_enabled': 'true',
      'user_preferences_json': '{"planningStyle":"quiet"}',
    });
    expect(backup['settings'], isNot(contains('settings')));
    expect(backup['settings'], isNot(contains('app_theme_entity_v1')));
    expect(backup['recordCounts'], <String, int>{
      'tasks': 1,
      'goals': 0,
      'habits': 0,
      'notes': 0,
      'task_occurrences': 0,
      'habit_occurrences': 0,
      'decision_outcomes': 0,
      'profile': 1,
      'settings': 3,
    });
  });

  test('portable local backup round trips every canonical domain', () async {
    await repository.saveTask(
      TaskEntity(
        id: 'task-round-trip',
        title: 'Round trip task',
        createdAt: DateTime.utc(2026, 8, 30, 10),
      ),
    );
    goalRepository.values = <GoalEntity>[
      GoalEntity(
        id: 'goal-round-trip',
        title: 'Round trip goal',
        createdAt: DateTime.utc(2026, 8, 30, 9),
      ),
    ];
    habitRepository.values = <HabitEntity>[
      HabitEntity(
        id: 'habit-round-trip',
        title: 'Morning rhythm',
        createdAt: DateTime.utc(2026, 8, 30, 8),
        updatedAt: DateTime.utc(2026, 8, 30, 8, 30),
      ),
    ];
    noteRepository.values = <NoteEntity>[
      NoteEntity(
        id: 'note-round-trip',
        title: 'Portable reflection',
        createdAt: DateTime.utc(2026, 8, 30, 7),
        kind: NoteKind.reflection,
        habitId: 'habit-round-trip',
        occurrenceId: 'habit-round-trip::2026-08-30',
        outcomeId: 'decision-round-trip::accepted::nexus',
      ),
    ];
    await occurrenceRepository.save(
      TaskOccurrence(
        taskId: 'task-round-trip',
        seriesId: 'task-round-trip',
        occurrenceKey: '2026-08-30T10:00:00.000Z',
        initialScheduledFor: DateTime.utc(2026, 8, 30, 10),
      ),
    );
    await decisionOutcomeRepository.record(
      DecisionOutcomeEntity(
        decisionId: 'decision-round-trip',
        kind: DecisionOutcomeKind.accepted,
        surface: 'nexus',
        recordedAt: DateTime.utc(2026, 8, 30, 11),
        modelVersion: 'local-v1',
        recommendationConfidence: 0.75,
      ),
    );
    await habitOccurrenceRepository.save(
      HabitOccurrenceEntity(
        habitId: 'habit-round-trip',
        occurrenceKey: '2026-08-30',
        operationId: 'habit-op-round-trip',
        outcome: HabitOccurrenceOutcome.completed,
        recordedAt: DateTime.utc(2026, 8, 30, 11, 30),
      ),
    );

    final Map<String, dynamic> backup = await service.createFullBackup();

    repository.clear();
    goalRepository.values = <GoalEntity>[];
    habitRepository.values = <HabitEntity>[];
    noteRepository.values = <NoteEntity>[];
    await occurrenceRepository.replaceSnapshot(const <TaskOccurrence>[]);
    await habitOccurrenceRepository.replaceSnapshot(
      const <HabitOccurrenceEntity>[],
    );
    await decisionOutcomeRepository.replaceSnapshot(
      const <DecisionOutcomeEntity>[],
    );
    await service.restoreFullBackup(backup);

    expect((await repository.getAllTasks()).single.id, 'task-round-trip');
    expect(goalRepository.values.single.id, 'goal-round-trip');
    expect(habitRepository.values.single.id, 'habit-round-trip');
    expect(noteRepository.values.single.id, 'note-round-trip');
    expect(noteRepository.values.single.kind, NoteKind.reflection);
    expect(
      noteRepository.values.single.occurrenceId,
      'habit-round-trip::2026-08-30',
    );
    expect(
      (await occurrenceRepository.listOccurrences()).single.taskId,
      'task-round-trip',
    );
    expect(
      decisionOutcomeRepository.values.single.decisionId,
      'decision-round-trip',
    );
    expect(
      (await habitOccurrenceRepository.load()).single.habitId,
      'habit-round-trip',
    );
    expect(backup['recordCounts'], <String, int>{
      'tasks': 1,
      'goals': 1,
      'habits': 1,
      'notes': 1,
      'task_occurrences': 1,
      'habit_occurrences': 1,
      'decision_outcomes': 1,
      'profile': 0,
      'settings': 0,
    });
    expect(
      (backup['manifest'] as Map<String, dynamic>)['cloudRestoreIncluded'],
      isFalse,
    );
  });

  test('full restore rejects a different account before any write', () async {
    await repository.saveTask(
      TaskEntity(
        id: 'existing-owner-a',
        title: 'Keep owner A data',
        createdAt: DateTime.utc(2026, 8, 30),
      ),
    );
    final Map<String, dynamic> backup = await service.createFullBackup();
    backup['account'] = <String, dynamic>{
      'namespace': AccountDataRegistry.accountNamespace('account-b'),
      'accountDigest': AccountDataRegistry.accountDigest('account-b'),
    };

    await expectLater(
      () => service.restoreFullBackup(backup),
      throwsFormatException,
    );

    expect((await repository.getAllTasks()).single.id, 'existing-owner-a');
  });

  test(
    'full restore rolls every canonical domain back on a late failure',
    () async {
      await repository.saveTask(
        TaskEntity(
          id: 'incoming-task',
          title: 'Incoming task',
          createdAt: DateTime.utc(2026, 8, 30, 10),
        ),
      );
      goalRepository.values = <GoalEntity>[
        GoalEntity(
          id: 'incoming-goal',
          title: 'Incoming goal',
          createdAt: DateTime.utc(2026, 8, 30, 10),
        ),
      ];
      habitRepository.values = <HabitEntity>[
        HabitEntity(
          id: 'incoming-habit',
          title: 'Incoming habit',
          createdAt: DateTime.utc(2026, 8, 30, 10),
          updatedAt: DateTime.utc(2026, 8, 30, 10),
        ),
      ];
      noteRepository.values = <NoteEntity>[
        NoteEntity(
          id: 'incoming-note',
          title: 'Incoming note',
          createdAt: DateTime.utc(2026, 8, 30, 10),
        ),
      ];
      await occurrenceRepository.replaceSnapshot(<TaskOccurrence>[
        const TaskOccurrence(
          taskId: 'incoming-task',
          seriesId: 'incoming-task',
          occurrenceKey: 'incoming-occurrence',
          initialScheduledFor: null,
        ),
      ]);
      decisionOutcomeRepository.values = <DecisionOutcomeEntity>[
        DecisionOutcomeEntity(
          decisionId: 'incoming-decision',
          kind: DecisionOutcomeKind.accepted,
          surface: 'nexus',
          recordedAt: DateTime.utc(2026, 8, 30, 10),
          modelVersion: 'local-v1',
          recommendationConfidence: 0.7,
        ),
      ];
      final Map<String, dynamic> incoming = await service.createFullBackup();

      repository.clear();
      await repository.saveTask(
        TaskEntity(
          id: 'original-task',
          title: 'Original task',
          createdAt: DateTime.utc(2026, 8, 29, 10),
        ),
      );
      goalRepository.values = <GoalEntity>[
        GoalEntity(
          id: 'original-goal',
          title: 'Original goal',
          createdAt: DateTime.utc(2026, 8, 29, 10),
        ),
      ];
      habitRepository.values = <HabitEntity>[
        HabitEntity(
          id: 'original-habit',
          title: 'Original habit',
          createdAt: DateTime.utc(2026, 8, 29, 10),
          updatedAt: DateTime.utc(2026, 8, 29, 10),
        ),
      ];
      noteRepository.values = <NoteEntity>[
        NoteEntity(
          id: 'original-note',
          title: 'Original note',
          createdAt: DateTime.utc(2026, 8, 29, 10),
        ),
      ];
      await occurrenceRepository.replaceSnapshot(<TaskOccurrence>[
        const TaskOccurrence(
          taskId: 'original-task',
          seriesId: 'original-task',
          occurrenceKey: 'original-occurrence',
          initialScheduledFor: null,
        ),
      ]);
      decisionOutcomeRepository.values = <DecisionOutcomeEntity>[
        DecisionOutcomeEntity(
          decisionId: 'original-decision',
          kind: DecisionOutcomeKind.shown,
          surface: 'nexus',
          recordedAt: DateTime.utc(2026, 8, 29, 10),
          modelVersion: 'local-v1',
          recommendationConfidence: 0.6,
        ),
      ];
      decisionOutcomeRepository.failNextReplace = true;

      await expectLater(
        () => service.restoreFullBackup(incoming),
        throwsStateError,
      );

      expect((await repository.getAllTasks()).single.id, 'original-task');
      expect(goalRepository.values.single.id, 'original-goal');
      expect(habitRepository.values.single.id, 'original-habit');
      expect(noteRepository.values.single.id, 'original-note');
      expect(
        (await occurrenceRepository.listOccurrences()).single.taskId,
        'original-task',
      );
      expect(
        decisionOutcomeRepository.values.single.decisionId,
        'original-decision',
      );
    },
  );

  test(
    'restore preview validates and counts without changing local data',
    () async {
      await repository.saveTask(
        TaskEntity(
          id: 'preview-task',
          title: 'Preview only',
          createdAt: DateTime.utc(2026, 8, 30),
        ),
      );
      await profileStorage.put(
        'profile_state',
        jsonEncode(<String, dynamic>{'name': 'Preview Person'}),
      );
      await service.prefs.setBool('cloud_sync_enabled_v1', true);
      await service.prefs.setString('reflection_reminder_time', '20:15');
      final Map<String, dynamic> backup = await service.createFullBackup();
      final int generationBefore = service.localGeneration;

      final BackupRestorePreview preview = service.previewFullRestore(backup);

      expect(preview.backupVersion, '5.0.0');
      expect(preview.isLegacyEnvelope, isFalse);
      expect(preview.recordCounts, <String, int>{
        'tasks': 1,
        'goals': 0,
        'habits': 0,
        'notes': 0,
        'task_occurrences': 0,
        'habit_occurrences': 0,
        'decision_outcomes': 0,
        'profile': 1,
        'settings': 2,
      });
      expect(preview.totalRecordCount, 4);
      expect(
        preview.includedDomains,
        containsAll(<String>['tasks', 'profile']),
      );
      expect((await repository.getAllTasks()).single.id, 'preview-task');
      expect(service.localGeneration, generationBefore);
    },
  );

  test('restore preview identifies supported legacy envelopes', () {
    final Map<String, dynamic> legacy = _fullBackup(
      tasks: <Map<String, dynamic>>[],
      profile: null,
      settings: <String, dynamic>{},
    );
    legacy['version'] = '3.0.0';
    final BackupRestorePreview preview = service.previewFullRestore(legacy);

    expect(preview.backupVersion, '3.0.0');
    expect(preview.isLegacyEnvelope, isTrue);
    expect(preview.totalRecordCount, 0);
  });

  test(
    'current backup rejects a mismatched record count before writes',
    () async {
      await repository.saveTask(
        TaskEntity(
          id: 'counted-task',
          title: 'Count me',
          createdAt: DateTime.utc(2026, 8, 30),
        ),
      );
      final Map<String, dynamic> backup = await service.createFullBackup();
      backup['recordCounts'] = <String, int>{
        'tasks': 0,
        'profile': 0,
        'settings': 0,
      };

      expect(() => service.previewFullRestore(backup), throwsFormatException);
      await expectLater(
        () => service.restoreFullBackup(backup),
        throwsFormatException,
      );
      expect((await repository.getAllTasks()).single.id, 'counted-task');
    },
  );

  test(
    'current restore rejects a stale local generation before writes',
    () async {
      final Map<String, dynamic> backup = await service.createFullBackup();

      await expectLater(
        () => service.restoreFullBackup(
          backup,
          expectedLocalGeneration: service.localGeneration + 1,
        ),
        throwsA(isA<BackupConcurrentMutationException>()),
      );
      expect(await repository.getAllTasks(), isEmpty);
    },
  );

  test('preflight covers precise JSON and manifest boundaries', () {
    final Map<String, dynamic> wrongCount = _fullBackup(
      tasks: <Map<String, dynamic>>[],
      profile: null,
      settings: <String, dynamic>{},
    );
    final Map<String, int> counts = Map<String, int>.from(
      wrongCount['recordCounts'] as Map<String, int>,
    );
    counts['tasks'] = 1;
    wrongCount['recordCounts'] = counts;
    expect(() => service.validateFullBackup(wrongCount), throwsFormatException);

    final Map<String, dynamic> duplicateManifestMember = _fullBackup(
      tasks: <Map<String, dynamic>>[],
      profile: null,
      settings: <String, dynamic>{},
    );
    final Map<String, dynamic> manifest = Map<String, dynamic>.from(
      duplicateManifestMember['manifest'] as Map<String, dynamic>,
    );
    final List<String> includedDomains = List<String>.from(
      manifest['includedDomains'] as List<dynamic>,
    );
    includedDomains.add(includedDomains.first);
    manifest['includedDomains'] = includedDomains;
    duplicateManifestMember['manifest'] = manifest;
    expect(
      () => service.validateFullBackup(duplicateManifestMember),
      throwsFormatException,
    );

    final Map<String, dynamic> nestedList = _fullBackup(
      tasks: <Map<String, dynamic>>[],
      profile: <String, dynamic>{
        'history': <Object?>[1, 'complete'],
      },
      settings: <String, dynamic>{},
    );
    expect(() => service.validateFullBackup(nestedList), returnsNormally);

    final Map<String, dynamic> nonFinite = _fullBackup(
      tasks: <Map<String, dynamic>>[],
      profile: <String, dynamic>{'score': double.nan},
      settings: <String, dynamic>{},
    );
    expect(() => service.validateFullBackup(nonFinite), throwsFormatException);

    Object? deeplyNested = 'leaf';
    for (int depth = 0; depth < 52; depth++) {
      deeplyNested = <Object?>[deeplyNested];
    }
    final Map<String, dynamic> excessiveNesting = _fullBackup(
      tasks: <Map<String, dynamic>>[],
      profile: <String, dynamic>{'nested': deeplyNested},
      settings: <String, dynamic>{},
    );
    expect(
      () => service.validateFullBackup(excessiveNesting),
      throwsFormatException,
    );
  });

  test('preflight rejects malformed canonical domain shapes precisely', () {
    Map<String, dynamic> emptyBackup() => _fullBackup(
      tasks: <Map<String, dynamic>>[],
      profile: null,
      settings: <String, dynamic>{},
    );

    final List<Map<String, dynamic>> invalidBackups = <Map<String, dynamic>>[];

    final Map<String, dynamic> missingRequired = emptyBackup()..remove('tasks');
    invalidBackups.add(missingRequired);

    final Map<String, dynamic> nonListRecords = emptyBackup()
      ..['tasks'] = <String, dynamic>{};
    invalidBackups.add(nonListRecords);

    invalidBackups.add(
      _fullBackup(
        tasks: <Map<String, dynamic>>[],
        profile: null,
        settings: <String, dynamic>{},
        goals: <Map<String, dynamic>>[
          <String, dynamic>{
            ...GoalEntity(
              id: 'goal-with-space',
              title: 'Goal',
              createdAt: DateTime.utc(2026, 9, 3),
            ).toJson(),
            'id': ' goal-with-space',
          },
        ],
      ),
    );

    final Map<String, dynamic> malformedAccount = emptyBackup()
      ..['account'] = <Object?, Object?>{1: 'not-a-string-key'};
    invalidBackups.add(malformedAccount);

    final Map<String, dynamic> malformedManifest = emptyBackup();
    malformedManifest['manifest'] = <String, dynamic>{
      ...malformedManifest['manifest'] as Map<String, dynamic>,
      'includedDomains': <Object?>[1],
    };
    invalidBackups.add(malformedManifest);

    invalidBackups.add(
      _fullBackup(
        tasks: <Map<String, dynamic>>[],
        profile: null,
        settings: <String, dynamic>{},
        habits: <Map<String, dynamic>>[
          <String, dynamic>{
            ...HabitEntity(
              id: 'habit-1',
              title: 'Walk',
              createdAt: DateTime.utc(2026, 9, 3),
              updatedAt: DateTime.utc(2026, 9, 3),
            ).toJson(),
            'stepTaskIds': <Object?>[1],
          },
        ],
      ),
    );

    invalidBackups.add(
      _fullBackup(
        tasks: <Map<String, dynamic>>[],
        profile: null,
        settings: <String, dynamic>{},
        notes: <Map<String, dynamic>>[
          <String, dynamic>{
            ...NoteEntity(
              id: 'note-1',
              title: 'Note',
              createdAt: DateTime.utc(2026, 9, 3),
            ).toJson(),
            'body': 7,
          },
        ],
      ),
    );

    invalidBackups.add(
      _fullBackup(
        tasks: <Map<String, dynamic>>[],
        profile: null,
        settings: <String, dynamic>{},
        taskOccurrences: <Map<String, dynamic>>[
          <String, dynamic>{'pendingOperation': 'not-an-object'},
        ],
      ),
    );

    invalidBackups.add(
      _fullBackup(
        tasks: <Map<String, dynamic>>[],
        profile: null,
        settings: <String, dynamic>{},
        decisionOutcomes: <Map<String, dynamic>>[
          <String, dynamic>{
            'decisionId': 'decision-1',
            'surface': 'timeline',
            'modelVersion': 'test-v1',
            'recordedAt': '2026-09-03T00:00:00.000Z',
            'subjectId': 7,
          },
        ],
      ),
    );

    for (int index = 0; index < invalidBackups.length; index += 1) {
      expect(
        () => service.validateFullBackup(invalidBackups[index]),
        throwsFormatException,
        reason: 'invalid canonical backup case $index must fail closed',
      );
    }
  });

  test('backupProfile and backupSettings expose stored state', () async {
    await profileStorage.put(
      'profile_state',
      jsonEncode(<String, dynamic>{'name': 'Nova', 'xp': 7}),
    );
    await service.prefs.setString('reflection_reminder_time', '19:45');

    final Map<String, dynamic> profileBackup = await service.backupProfile();
    final Map<String, dynamic> settingsBackup = await service.backupSettings();

    expect(profileBackup['profile'], <String, dynamic>{
      'name': 'Nova',
      'xp': 7,
    });
    expect(settingsBackup['settings'], <String, dynamic>{
      'reflection_reminder_time': '19:45',
    });
    expect(profileBackup['timestamp'], isA<String>());
    expect(settingsBackup['timestamp'], isA<String>());
  });

  test(
    'backupProfile distinguishes missing profile from preserved corruption',
    () async {
      expect((await service.backupProfile())['profile'], isNull);

      await profileStorage.put('profile_state', '{not valid json');

      await expectLater(service.backupProfile(), throwsFormatException);
      expect(profileStorage.get('profile_state'), '{not valid json');
    },
  );

  test('export helpers serialize canonical backup payloads', () async {
    await repository.saveTask(
      TaskEntity(
        id: 'task-1',
        title: 'Export me',
        createdAt: DateTime.utc(2026, 7, 5),
      ),
    );
    await profileStorage.put(
      'profile_state',
      jsonEncode(<String, dynamic>{'name': 'Exporter'}),
    );

    final Map<String, dynamic> fullBackup =
        jsonDecode(await service.exportFullBackupString())
            as Map<String, dynamic>;
    final Map<String, dynamic> tasksBackup =
        jsonDecode(await service.exportTasksString()) as Map<String, dynamic>;

    expect(fullBackup['version'], '5.0.0');
    expect(
      (fullBackup['tasks'] as List<dynamic>).single,
      isA<Map<String, dynamic>>(),
    );
    expect(
      (tasksBackup['tasks'] as List<dynamic>).single,
      isA<Map<String, dynamic>>(),
    );
  });

  test(
    'restoreFullBackup restores profile and settings alongside tasks',
    () async {
      await service.restoreFullBackup(
        _fullBackup(
          tasks: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'restored',
              'title': 'Restored task',
              'createdAt': '2026-07-05T08:00:00.000Z',
            },
          ],
          profile: <String, dynamic>{'name': 'Recovered', 'xp': 12},
          settings: <String, dynamic>{
            'cloud_sync_enabled_v1': true,
            'reflection_reminder_enabled': 'true',
          },
        ),
      );

      expect((await repository.getAllTasks()).single.id, 'restored');
      expect(
        profileStorage.get('profile_state'),
        jsonEncode(<String, dynamic>{'name': 'Recovered', 'xp': 12}),
      );
      expect(service.prefs.getBool('cloud_sync_enabled_v1'), isTrue);
      expect(service.prefs.getString('reflection_reminder_enabled'), 'true');
    },
  );

  test('full restore replaces only allowlisted account settings', () async {
    await service.prefs.setBool('cloud_sync_enabled_v1', true);
    await service.prefs.setString('reflection_reminder_time', '18:30');
    await service.prefs.setString('app_theme_entity_v1', 'device-theme');
    await service.prefs.setBool('onboarding_complete', true);
    await service.prefs.setJson('settings', <String, dynamic>{
      'legacy': 'preserve until cleanup',
    });

    await service.restoreFullBackup(
      _fullBackup(
        tasks: <Map<String, dynamic>>[],
        profile: null,
        settings: <String, dynamic>{
          'goal_reminders_enabled': 'false',
          'reflection_reminder_time': '21:05',
        },
      ),
    );

    expect(service.prefs.getBool('cloud_sync_enabled_v1'), isNull);
    expect(service.prefs.getString('goal_reminders_enabled'), 'false');
    expect(service.prefs.getString('reflection_reminder_time'), '21:05');
    expect(service.prefs.getString('app_theme_entity_v1'), 'device-theme');
    expect(service.prefs.getBool('onboarding_complete'), isTrue);
    expect(service.prefs.getJson('settings'), <String, dynamic>{
      'legacy': 'preserve until cleanup',
    });
  });

  test(
    'restore rejects unknown or mistyped account settings before writes',
    () async {
      await service.prefs.setString('reflection_reminder_time', '18:30');

      for (final Map<String, dynamic> invalid in <Map<String, dynamic>>[
        <String, dynamic>{'app_theme_entity_v1': 'remote-theme'},
        <String, dynamic>{'cloud_sync_enabled_v1': 'true'},
        <String, dynamic>{'reflection_reminder_enabled': true},
        <String, dynamic>{'daily_planning_reminder_time': '25:99'},
        <String, dynamic>{'user_preferences_json': 'not-json'},
      ]) {
        await expectLater(
          () => service.restoreSettings(<String, dynamic>{'settings': invalid}),
          throwsFormatException,
        );
        expect(service.prefs.getString('reflection_reminder_time'), '18:30');
      }
    },
  );

  test('settings rollback restores exact native values and absence', () async {
    final SharedPreferences rawPrefs = await SharedPreferences.getInstance();
    await rawPrefs.setBool('cloud_sync_enabled_v1', false);
    await rawPrefs.setString('goal_reminders_enabled', 'true');
    await rawPrefs.setString('app_theme_entity_v1', 'device-theme');
    final _WriteThenFailPrefsStorage failingPrefs = _WriteThenFailPrefsStorage(
      rawPrefs,
    );
    final BackupService failingService = buildService(
      taskRepository: repository,
      profileStorage: profileStorage,
      prefs: failingPrefs,
    );

    await expectLater(
      () => failingService.restoreSettings(<String, dynamic>{
        'settings': <String, dynamic>{'reflection_reminder_time': '20:00'},
      }),
      throwsStateError,
    );

    expect(failingPrefs.getBool('cloud_sync_enabled_v1'), isFalse);
    expect(failingPrefs.getString('goal_reminders_enabled'), 'true');
    expect(failingPrefs.contains('reflection_reminder_time'), isFalse);
    expect(failingPrefs.getString('app_theme_entity_v1'), 'device-theme');
  });

  test(
    'settings rollback restores every supported native value type',
    () async {
      final SharedPreferences rawPrefs = await SharedPreferences.getInstance();
      await rawPrefs.setInt('cloud_sync_enabled_v1', 7);
      await rawPrefs.setDouble('goal_reminders_enabled', 1.5);
      await rawPrefs.setStringList('reflection_reminder_enabled', <String>[
        'true',
      ]);
      final _WriteThenFailPrefsStorage failingPrefs =
          _WriteThenFailPrefsStorage(rawPrefs);
      final BackupService failingService = buildService(
        taskRepository: repository,
        profileStorage: profileStorage,
        prefs: failingPrefs,
      );

      await expectLater(
        () => failingService.restoreSettings(<String, dynamic>{
          'settings': <String, dynamic>{'reflection_reminder_time': '20:00'},
        }),
        throwsStateError,
      );

      expect(rawPrefs.getInt('cloud_sync_enabled_v1'), 7);
      expect(rawPrefs.getDouble('goal_reminders_enabled'), 1.5);
      expect(rawPrefs.getStringList('reflection_reminder_enabled'), <String>[
        'true',
      ]);
    },
  );

  test(
    'restoreFullBackup rejects incomplete legacy envelopes before writes',
    () async {
      await repository.saveTask(
        TaskEntity(
          id: 'existing',
          title: 'Keep task',
          createdAt: DateTime.utc(2026, 7, 1),
        ),
      );
      await service.prefs.setString('reflection_reminder_time', '18:30');

      await expectLater(
        () => service.restoreFullBackup(<String, dynamic>{
          'tasks': <Map<String, dynamic>>[],
          'user': <String, dynamic>{'name': 'Legacy Restore'},
          'settings': 'not a map',
        }),
        throwsFormatException,
      );

      expect((await repository.getAllTasks()).single.id, 'existing');
      await profileStorage.open();
      expect(profileStorage.get('profile_state'), isNull);
      expect(service.prefs.getString('reflection_reminder_time'), '18:30');
    },
  );

  test('restoreProfile supports legacy user payload fallback', () async {
    await service.restoreProfile(<String, dynamic>{
      'user': <String, dynamic>{'name': 'Legacy Pilot'},
    });

    expect(
      profileStorage.get('profile_state'),
      jsonEncode(<String, dynamic>{
        'xp': 0,
        'level': 1,
        'streak': 0,
        'longestStreak': 0,
        'name': 'Legacy Pilot',
        'soundEnabled': true,
        'lastActiveDate': null,
      }),
    );
  });

  test(
    'restoreProfile ignores blank legacy users and restoreSettings ignores non-map payloads',
    () async {
      await profileStorage.put(
        'profile_state',
        jsonEncode(<String, dynamic>{'name': 'Keep Me'}),
      );
      await service.prefs.setString('reflection_reminder_time', '18:30');

      await expectLater(
        () => service.restoreProfile(<String, dynamic>{
          'user': <String, dynamic>{'name': '   '},
        }),
        throwsFormatException,
      );
      await expectLater(
        () => service.restoreSettings(<String, dynamic>{'settings': 'invalid'}),
        throwsFormatException,
      );

      expect(
        profileStorage.get('profile_state'),
        jsonEncode(<String, dynamic>{'name': 'Keep Me'}),
      );
      expect(service.prefs.getString('reflection_reminder_time'), '18:30');
    },
  );

  test('restoreTasks rejects missing or invalid tasks payload', () async {
    await repository.saveTask(
      TaskEntity(
        id: 'keep',
        title: 'Keep me',
        createdAt: DateTime.utc(2026, 7, 5),
      ),
    );

    await expectLater(
      () => service.restoreTasks(<String, dynamic>{'tasks': 'invalid'}),
      throwsFormatException,
    );

    expect((await repository.getAllTasks()).single.id, 'keep');
  });

  test('restoreTasks throws when backup has no valid task records', () async {
    await expectLater(
      () => service.restoreTasks(<String, dynamic>{
        'tasks': <Map<String, dynamic>>[
          <String, dynamic>{'title': 'Missing required id and createdAt'},
        ],
      }),
      throwsFormatException,
    );
  });

  test(
    'restoreTasks rejects mixed malformed records and duplicate IDs',
    () async {
      final Map<String, dynamic> validTask = <String, dynamic>{
        'id': 'duplicate',
        'title': 'Valid task',
        'createdAt': '2026-08-02T00:00:00.000Z',
      };

      await expectLater(
        () => service.restoreTasks(<String, dynamic>{
          'tasks': <Object?>[
            validTask,
            <String, dynamic>{'id': 'broken', 'title': 'Missing date'},
          ],
        }),
        throwsFormatException,
      );
      await expectLater(
        () => service.restoreTasks(<String, dynamic>{
          'tasks': <Object?>[validTask, Map<String, dynamic>.from(validTask)],
        }),
        throwsFormatException,
      );
      expect(await repository.getAllTasks(), isEmpty);
    },
  );

  test(
    'restoreTasks rejects invalid optional field types and bounds',
    () async {
      final Map<String, dynamic> validTask = <String, dynamic>{
        'id': 'invalid-optional-field',
        'title': 'Invalid optional field',
        'createdAt': '2026-08-02T00:00:00.000Z',
      };
      final List<Map<String, dynamic>> invalidFields = <Map<String, dynamic>>[
        <String, dynamic>{'isCompleted': 'yes'},
        <String, dynamic>{'priority': -1},
        <String, dynamic>{'description': 7},
        <String, dynamic>{
          'description': List<String>.filled(100001, 'x').join(),
        },
      ];

      for (final Map<String, dynamic> invalidField in invalidFields) {
        await expectLater(
          () => service.restoreTasks(<String, dynamic>{
            'tasks': <Map<String, dynamic>>[
              <String, dynamic>{...validTask, ...invalidField},
            ],
          }),
          throwsFormatException,
        );
      }
      expect(await repository.getAllTasks(), isEmpty);
    },
  );

  test(
    'full restore preflight rejects invalid manifest before any write',
    () async {
      await repository.saveTask(
        TaskEntity(
          id: 'existing',
          title: 'Keep me',
          createdAt: DateTime.utc(2026, 8, 1),
        ),
      );
      await profileStorage.put(
        'profile_state',
        jsonEncode(<String, dynamic>{'name': 'Existing'}),
      );
      await service.prefs.setString('reflection_reminder_time', '18:30');
      final Map<String, dynamic> backup = _fullBackup(
        tasks: <Map<String, dynamic>>[],
        profile: <String, dynamic>{'name': 'Incoming'},
        settings: <String, dynamic>{'reflection_reminder_time': '20:00'},
      );
      final Map<String, dynamic> manifest = Map<String, dynamic>.from(
        backup['manifest'] as Map<String, dynamic>,
      );
      manifest['includedDomains'] = <String>['tasks'];
      backup['manifest'] = manifest;

      await expectLater(
        () => service.restoreFullBackup(backup),
        throwsFormatException,
      );

      expect((await repository.getAllTasks()).single.id, 'existing');
      expect(
        profileStorage.get('profile_state'),
        jsonEncode(<String, dynamic>{'name': 'Existing'}),
      );
      expect(service.prefs.getString('reflection_reminder_time'), '18:30');
    },
  );

  test(
    'full restore preflight rejects nested non-JSON data before writes',
    () async {
      await repository.saveTask(
        TaskEntity(
          id: 'existing',
          title: 'Keep me',
          createdAt: DateTime.utc(2026, 8, 1),
        ),
      );
      await profileStorage.put(
        'profile_state',
        jsonEncode(<String, dynamic>{'name': 'Existing'}),
      );
      await service.prefs.setString('reflection_reminder_time', '18:30');
      final Map<String, dynamic> backup = _fullBackup(
        tasks: <Map<String, dynamic>>[],
        profile: <String, dynamic>{'name': 'Incoming'},
        settings: <String, dynamic>{'user_preferences_json': Object()},
      );

      await expectLater(
        () => service.restoreFullBackup(backup),
        throwsFormatException,
      );

      expect((await repository.getAllTasks()).single.id, 'existing');
      expect(
        profileStorage.get('profile_state'),
        jsonEncode(<String, dynamic>{'name': 'Existing'}),
      );
      expect(service.prefs.getString('reflection_reminder_time'), '18:30');
    },
  );

  test(
    'failed restore preserves exact secure and legacy profile states',
    () async {
      const List<({String? secure, String? legacy})> cases =
          <({String? secure, String? legacy})>[
            (secure: null, legacy: null),
            (secure: null, legacy: '{"name":"Legacy only"}'),
            (secure: '{"name":"Secure only"}', legacy: null),
            (secure: '{"name":"Secure"}', legacy: '{"name":"Legacy"}'),
          ];

      for (final ({String? secure, String? legacy}) profileCase in cases) {
        await profileStorage.clear();
        if (profileCase.legacy != null) {
          await profileStorage.put('profile_state', profileCase.legacy!);
        }
        final InMemorySecureStoreBackend backend = InMemorySecureStoreBackend();
        final SecureStore secureStore = SecureStore(backend: backend);
        if (profileCase.secure != null) {
          await secureStore.writeString(
            'profile_state_v2',
            profileCase.secure!,
          );
        }
        final SharedPreferences rawPrefs =
            await SharedPreferences.getInstance();
        for (final String key
            in AccountDataRegistry.accountPreferenceBackupKeys) {
          await rawPrefs.remove(key);
        }
        final BackupService exactService = buildService(
          taskRepository: repository,
          profileStorage: profileStorage,
          prefs: _WriteThenFailPrefsStorage(rawPrefs),
          secureProfileStore: secureStore,
        );

        await expectLater(
          () => exactService.restoreFullBackup(
            _fullBackup(
              tasks: <Map<String, dynamic>>[],
              profile: <String, dynamic>{'name': 'Incoming'},
              settings: <String, dynamic>{'reflection_reminder_time': '20:00'},
            ),
          ),
          throwsStateError,
        );

        expect(
          await secureStore.readString('profile_state_v2'),
          profileCase.secure,
        );
        expect(profileStorage.get('profile_state'), profileCase.legacy);
      }
    },
  );

  test(
    'full restore rolls newly created profile and settings back to absence',
    () async {
      await repository.saveTask(
        TaskEntity(
          id: 'existing',
          title: 'Keep me',
          createdAt: DateTime.utc(2026, 8, 1),
        ),
      );
      final SharedPreferences rawPrefs = await SharedPreferences.getInstance();
      final _WriteThenFailPrefsStorage failingPrefs =
          _WriteThenFailPrefsStorage(rawPrefs);
      final BackupService failingService = buildService(
        taskRepository: repository,
        profileStorage: profileStorage,
        prefs: failingPrefs,
      );

      await expectLater(
        () => failingService.restoreFullBackup(
          _fullBackup(
            tasks: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'incoming',
                'title': 'Incoming',
                'createdAt': '2026-08-02T00:00:00.000Z',
              },
            ],
            profile: <String, dynamic>{'name': 'Incoming'},
            settings: <String, dynamic>{'reflection_reminder_time': '20:00'},
          ),
        ),
        throwsStateError,
      );

      expect((await repository.getAllTasks()).single.id, 'existing');
      expect(profileStorage.get('profile_state'), isNull);
      expect(failingPrefs.contains('reflection_reminder_time'), isFalse);
    },
  );

  test(
    'failed task replacement rolls back the complete prior task set',
    () async {
      await repository.saveTask(
        TaskEntity(
          id: 'existing',
          title: 'Preserve this task',
          createdAt: DateTime.utc(2026, 8, 1),
        ),
      );
      repository.failFirstSaveForId = 'restore-fails';

      await expectLater(
        () => service.restoreTasks(<String, dynamic>{
          'tasks': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'restore-starts',
              'title': 'Partially restored task',
              'createdAt': '2026-08-02T00:00:00.000Z',
            },
            <String, dynamic>{
              'id': 'restore-fails',
              'title': 'Triggers rollback',
              'createdAt': '2026-08-03T00:00:00.000Z',
            },
          ],
        }),
        throwsStateError,
      );

      final List<TaskEntity> tasks = await repository.getAllTasks();
      expect(tasks.map((TaskEntity task) => task.id), <String>['existing']);
    },
  );

  test('restore reports explicitly when rollback also fails', () async {
    await repository.saveTask(
      TaskEntity(
        id: 'existing',
        title: 'Existing',
        createdAt: DateTime.utc(2026, 8, 1),
      ),
    );
    repository.failFirstSaveForId = 'incoming';
    repository.failEverySaveForId = 'existing';

    await expectLater(
      () => service.restoreTasks(<String, dynamic>{
        'tasks': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'incoming',
            'title': 'Incoming',
            'createdAt': '2026-08-02T00:00:00.000Z',
          },
        ],
      }),
      throwsA(isA<BackupRestoreRollbackException>()),
    );
  });

  test('account data clear waits for restore rollback to finish', () async {
    final KeyedMutationCoordinator coordinator = KeyedMutationCoordinator();
    final Completer<void> writeStarted = Completer<void>();
    final Completer<void> releaseWrite = Completer<void>();
    final BackupService coordinatedService = buildService(
      taskRepository: repository,
      profileStorage: profileStorage,
      prefs: service.prefs,
      mutationCoordinator: coordinator,
    );
    await repository.saveTask(
      TaskEntity(
        id: 'existing',
        title: 'Restore during rollback',
        createdAt: DateTime.utc(2026, 8, 1),
      ),
    );
    repository.beforeSave = (TaskEntity task) async {
      if (task.id != 'incoming') return;
      writeStarted.complete();
      await releaseWrite.future;
      throw StateError('Simulated delayed restore failure.');
    };

    final Future<void> restore = coordinatedService.restoreTasks(
      <String, dynamic>{
        'tasks': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'incoming',
            'title': 'Incoming',
            'createdAt': '2026-08-02T00:00:00.000Z',
          },
        ],
      },
    );
    await writeStarted.future;
    bool clearRan = false;
    final Future<void> clear = runAccountStorageMutation(() async {
      clearRan = true;
      repository.clear();
    }, coordinator: coordinator);
    await Future<void>.delayed(Duration.zero);
    expect(clearRan, isFalse);

    releaseWrite.complete();
    await expectLater(restore, throwsStateError);
    await clear;

    expect(clearRan, isTrue);
    expect(await repository.getAllTasks(), isEmpty);
  });

  test(
    'migrates legacy profile data to secure storage before writes',
    () async {
      final SecureStore secureStore = SecureStore(
        backend: InMemorySecureStoreBackend(),
      );
      final BackupService secureService = buildService(
        taskRepository: repository,
        profileStorage: profileStorage,
        prefs: service.prefs,
        secureProfileStore: secureStore,
      );
      await profileStorage.put(
        'profile_state',
        jsonEncode(<String, dynamic>{'name': 'Legacy Secure User'}),
      );

      expect(
        (await secureService.backupProfile())['profile'],
        <String, dynamic>{'name': 'Legacy Secure User'},
      );
      expect(profileStorage.get('profile_state'), isNull);
      expect(
        await secureStore.readString('profile_state_v2'),
        jsonEncode(<String, dynamic>{'name': 'Legacy Secure User'}),
      );

      await secureService.restoreProfile(<String, dynamic>{
        'profile': <String, dynamic>{'name': 'Secure Restore'},
      });
      await secureService.restoreSettings(<String, dynamic>{
        'settings': <String, dynamic>{'cloud_sync_enabled_v1': false},
      });

      expect(
        await secureStore.readString('profile_state_v2'),
        jsonEncode(<String, dynamic>{'name': 'Secure Restore'}),
      );
      expect(secureService.prefs.getBool('cloud_sync_enabled_v1'), isFalse);
    },
  );

  test('full restore deletes an absent profile from secure storage', () async {
    final SecureStore secureStore = SecureStore(
      backend: InMemorySecureStoreBackend(),
    );
    await secureStore.writeString(
      'profile_state_v2',
      jsonEncode(<String, dynamic>{'name': 'Remove me'}),
    );
    final BackupService secureService = buildService(
      taskRepository: repository,
      profileStorage: profileStorage,
      prefs: service.prefs,
      secureProfileStore: secureStore,
    );

    await secureService.restoreFullBackup(
      _fullBackup(
        tasks: <Map<String, dynamic>>[],
        profile: null,
        settings: <String, dynamic>{},
      ),
    );

    expect(await secureStore.readString('profile_state_v2'), isNull);
    expect(profileStorage.get('profile_state'), isNull);
  });
}

class _MemoryTaskRepository implements ITaskRepository {
  final Map<String, TaskEntity> _tasks = <String, TaskEntity>{};
  String? failFirstSaveForId;
  String? failEverySaveForId;
  bool _didFailConfiguredSave = false;
  Future<void> Function(TaskEntity task)? beforeSave;
  int readCount = 0;

  void clear() => _tasks.clear();

  @override
  Future<void> deleteTask(String id) async {
    _tasks.remove(id);
  }

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    readCount++;
    return _tasks.values.toList(growable: false);
  }

  @override
  Future<TaskEntity?> getTaskById(String id) async {
    return _tasks[id];
  }

  @override
  Future<void> saveTask(TaskEntity task) async {
    await beforeSave?.call(task);
    if (task.id == failEverySaveForId) {
      throw StateError('Simulated persistent save failure for ${task.id}.');
    }
    if (!_didFailConfiguredSave && task.id == failFirstSaveForId) {
      _didFailConfiguredSave = true;
      throw StateError('Simulated restore write failure for ${task.id}.');
    }
    _tasks[task.id] = task;
  }
}

class _MemoryPrefsStore implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => values[key];

  @override
  Future<void> save(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> clear() async {
    values.clear();
  }
}

Map<String, dynamic> _fullBackup({
  required List<Map<String, dynamic>> tasks,
  required Map<String, dynamic>? profile,
  required Map<String, dynamic> settings,
  List<Map<String, dynamic>> goals = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> habits = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> notes = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> taskOccurrences = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> habitOccurrences = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> decisionOutcomes = const <Map<String, dynamic>>[],
}) {
  return <String, dynamic>{
    'version': '5.0.0',
    'manifest': accountDataBackupManifest(),
    'account': <String, dynamic>{
      'namespace': AccountDataRegistry.accountNamespace('account-a'),
      'accountDigest': AccountDataRegistry.accountDigest('account-a'),
    },
    'timestamp': '2026-08-29T12:00:00.000Z',
    'tasks': tasks,
    'goals': goals,
    'habits': habits,
    'notes': notes,
    'taskOccurrences': taskOccurrences,
    'habitOccurrences': habitOccurrences,
    'decisionOutcomes': decisionOutcomes,
    'profile': profile,
    'settings': settings,
    'recordCounts': <String, int>{
      'tasks': tasks.length,
      'goals': goals.length,
      'habits': habits.length,
      'notes': notes.length,
      'task_occurrences': taskOccurrences.length,
      'habit_occurrences': habitOccurrences.length,
      'decision_outcomes': decisionOutcomes.length,
      'profile': profile == null ? 0 : 1,
      'settings': settings.length,
    },
  };
}

class _MemoryGoalRepository implements IGoalRepository {
  List<GoalEntity> values = <GoalEntity>[];

  @override
  List<GoalEntity> getGoals() => List<GoalEntity>.unmodifiable(values);

  @override
  Future<void> saveGoal(GoalEntity goal) async {
    values.removeWhere((GoalEntity value) => value.id == goal.id);
    values.add(goal);
  }

  @override
  Future<void> saveGoals(List<GoalEntity> goals) async {
    values = List<GoalEntity>.from(goals);
  }

  @override
  Future<void> deleteGoal(String id) async {
    values.removeWhere((GoalEntity value) => value.id == id);
  }
}

class _MemoryHabitRepository implements IHabitRepository {
  List<HabitEntity> values = <HabitEntity>[];

  @override
  Future<List<HabitEntity>> getHabits() async =>
      List<HabitEntity>.unmodifiable(values);

  @override
  Future<void> saveHabits(List<HabitEntity> habits) async {
    values = List<HabitEntity>.from(habits);
  }
}

class _MemoryNoteRepository
    implements INoteRepository, IExactNoteSnapshotRepository {
  List<NoteEntity> values = <NoteEntity>[];

  @override
  Future<List<NoteEntity>> getNotes() async =>
      List<NoteEntity>.unmodifiable(values);

  @override
  Future<void> saveNote(NoteEntity note) async {
    values.removeWhere((NoteEntity value) => value.id == note.id);
    values.add(note);
  }

  @override
  Future<void> deleteNote(String id) async {
    values.removeWhere((NoteEntity value) => value.id == id);
  }

  @override
  Future<void> replaceNoteSnapshot(List<NoteEntity> notes) async {
    values = List<NoteEntity>.from(notes);
  }
}

class _MemoryDecisionOutcomeRepository
    implements
        IDecisionOutcomeRepository,
        IExactDecisionOutcomeSnapshotRepository {
  List<DecisionOutcomeEntity> values = <DecisionOutcomeEntity>[];
  bool failNextReplace = false;

  @override
  Future<List<DecisionOutcomeEntity>> load() async =>
      List<DecisionOutcomeEntity>.unmodifiable(values);

  @override
  Future<void> record(DecisionOutcomeEntity outcome) async {
    if (!values.any((DecisionOutcomeEntity value) => value.id == outcome.id)) {
      values.add(outcome);
    }
  }

  @override
  Future<void> replaceSnapshot(List<DecisionOutcomeEntity> outcomes) async {
    if (failNextReplace) {
      failNextReplace = false;
      throw StateError('Simulated decision outcome restore failure.');
    }
    values = List<DecisionOutcomeEntity>.from(outcomes);
  }
}

class _WriteThenFailPrefsStorage extends SharedPrefsStorage {
  _WriteThenFailPrefsStorage(super.prefs);

  bool _failed = false;

  @override
  Future<void> setString(String key, String value) async {
    await super.setString(key, value);
    if (!_failed) {
      _failed = true;
      throw StateError('Simulated settings write failure.');
    }
  }
}

class _TestHiveStore implements HiveStore {
  @override
  Box<T> box<T>(String key) => Hive.box<T>(key);

  @override
  Future<void> clearBox(String key) async {
    if (Hive.isBoxOpen(key)) {
      await Hive.box<String>(key).clear();
      return;
    }
    final Box<String> box = await Hive.openBox<String>(key);
    await box.clear();
    await box.close();
  }

  @override
  Future<void> closeBox(String key) async {
    if (Hive.isBoxOpen(key)) {
      await Hive.box<String>(key).close();
    }
  }

  @override
  Future<void> init() async {}

  @override
  bool isBoxOpen(String key) => Hive.isBoxOpen(key);

  @override
  Future<Box<T>> openBox<T>(String key) async {
    if (Hive.isBoxOpen(key)) {
      return Hive.box<T>(key);
    }
    return Hive.openBox<T>(key);
  }
}
