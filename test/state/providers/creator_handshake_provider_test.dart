import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/creator_handshake.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_note_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/creator_handshake_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/person_context_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('stage creates a bound preview without any mutation', () async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);

    final CreatorHandshakeState state = await harness.notifier.stage(
      data: const CreatorFormData(
        title: 'Verify the release decision',
        description: 'Use the reviewed evidence.',
        type: 'Task',
        priority: 4,
      ),
      source: CreatorHandshakeSource.smartPlanner,
    );

    expect(harness.repository.saveCalls, 0);
    expect(harness.repository.deleteCalls, 0);
    expect(state.phase, CreatorHandshakePhase.preview);
    expect(state.preview, isNotNull);
    expect(state.preview!.source, CreatorHandshakeSource.smartPlanner);
    expect(state.preview!.selectedOperations, hasLength(1));
    expect(
      state.preview!.selectedOperations.single.task.title,
      'Verify the release decision',
    );
    expect(state.token!.accountScopeId, state.preview!.accountScopeId);
    expect(state.token!.baseDomainRevision, state.preview!.baseDomainRevision);
    expect(
      state.token!.displayedDiffDigest,
      state.preview!.displayedDiffDigest,
    );
    expect(
      state.token!.validates(
        preview: state.preview!,
        currentAccountScopeId: state.preview!.accountScopeId,
        now: harness.now,
      ),
      isTrue,
    );
  });

  test('selective confirmation blocks an empty selection', () async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);
    await harness.notifier.stage(data: _taskData());
    final String operationId =
        harness.state.preview!.operations.single.operationId;

    harness.notifier.toggleOperation(operationId, selected: false);
    expect(harness.state.canConfirm, isFalse);
    expect(harness.state.token, isNull);

    final CreatorHandshakeState result = await harness.notifier.confirm();
    expect(result.phase, CreatorHandshakePhase.conflict);
    expect(harness.repository.saveCalls, 0);

    harness.notifier.toggleOperation(operationId, selected: true);
    expect(harness.state.canConfirm, isTrue);
    expect(harness.state.token, isNotNull);
  });

  test(
    'stage distinguishes unavailable from valid empty person context',
    () async {
      final _Harness unavailable = _Harness();
      addTearDown(unavailable.dispose);
      final CreatorHandshakeState unavailableState = await unavailable.notifier
          .stage(data: _taskData());

      expect(unavailableState.preview!.personContextBinding, isNull);

      final _Harness empty = _Harness();
      addTearDown(empty.dispose);
      empty.setPersonContext(_personContextView(empty.now));
      expect(empty.creatorPersonContext, isNotNull);
      final CreatorHandshakeState emptyState = await empty.notifier.stage(
        data: _taskData(),
      );

      final CreatorPersonContextBinding binding =
          emptyState.preview!.personContextBinding!;
      expect(binding.hasBoundEvidence, isFalse);
      expect(binding.evidenceSummary, isEmpty);
      expect(binding.revision, startsWith('person-context-v1-'));
      expect(empty.repository.saveCalls, 0);
    },
  );

  test(
    'person context is bound as review evidence without changing proposal',
    () async {
      final _Harness harness = _Harness();
      addTearDown(harness.dispose);
      harness.setPersonContext(
        _personContextView(
          harness.now,
          signals: <PersonContextSignal>[
            _personContextSignal(
              now: harness.now,
              id: 'priority',
              kind: PersonContextKind.currentPriority,
              value: 'Ship only after exact evidence',
            ),
            _personContextSignal(
              now: harness.now,
              id: 'capacity',
              kind: PersonContextKind.presentCapacity,
              value: 'Keep  this step\nsmall today',
            ),
            _personContextSignal(
              now: harness.now,
              id: 'boundary',
              kind: PersonContextKind.boundary,
              value: 'Do not infer consent',
            ),
            _personContextSignal(
              now: harness.now,
              id: 'commitment',
              kind: PersonContextKind.commitment,
              value: 'Review every bound item',
            ),
            _personContextSignal(
              now: harness.now,
              id: 'role',
              kind: PersonContextKind.role,
              value: 'Release lead',
            ),
          ],
        ),
      );

      final CreatorHandshakeState state = await harness.notifier.stage(
        data: _taskData(),
      );
      final CreatorHandshakePreview preview = state.preview!;
      final CreatorTaskMutation task = preview.operations.single.task;

      expect(preview.personContextBinding!.hasBoundEvidence, isTrue);
      expect(preview.personContextBinding!.evidenceSummary, const <String>[
        'currentPriority: Ship only after exact evidence',
        'presentCapacity: Keep  this step\nsmall today',
        'boundary: Do not infer consent',
        'commitment: Review every bound item',
      ]);
      expect(preview.operations.single.label, 'Create task');
      expect(state.message, contains('review evidence only'));
      expect(state.message, contains('did not alter the proposed task'));
      expect(task.title, _taskData().title);
      expect(task.description, _taskData().description);
      expect(task.priority, _taskData().priority);
      expect(task.scheduledFor, _taskData().scheduledFor);
      expect(harness.repository.saveCalls, 0);
      expect(
        state.token!.validates(
          preview: preview,
          currentAccountScopeId: preview.accountScopeId,
          now: harness.now,
        ),
        isTrue,
      );
      final CreatorHandshakePreview tamperedEvidence = preview.copyWith(
        personContextBinding: CreatorPersonContextBinding(
          revision: preview.personContextBinding!.revision,
          hasBoundEvidence: true,
          evidenceSummary: const <String>[
            'presentCapacity: Different unreviewed evidence',
          ],
        ),
      );
      expect(
        state.token!.validates(
          preview: tamperedEvidence,
          currentAccountScopeId: preview.accountScopeId,
          now: harness.now,
        ),
        isFalse,
      );
    },
  );

  test(
    'changed bound context evidence blocks confirmation before mutation',
    () async {
      final _Harness harness = _Harness();
      addTearDown(harness.dispose);
      harness.setPersonContext(
        _personContextView(
          harness.now,
          signals: <PersonContextSignal>[
            _personContextSignal(
              now: harness.now,
              id: 'priority',
              kind: PersonContextKind.currentPriority,
              value: 'Release evidence',
            ),
          ],
        ),
      );
      await harness.notifier.stage(data: _taskData());

      harness.setPersonContext(
        _personContextView(
          harness.now,
          signals: <PersonContextSignal>[
            _personContextSignal(
              now: harness.now,
              id: 'priority',
              kind: PersonContextKind.currentPriority,
              value: 'Pause release work',
            ),
          ],
        ),
      );
      final CreatorHandshakeState stale = await harness.notifier.confirm();

      expect(stale.phase, CreatorHandshakePhase.stale);
      expect(stale.token, isNull);
      expect(stale.receipt, isNull);
      expect(stale.message, contains('Person context changed'));
      expect(harness.repository.saveCalls, 0);
    },
  );

  test('context changed during domain revision blocks mutation', () async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);
    harness.setPersonContext(
      _personContextView(
        harness.now,
        signals: <PersonContextSignal>[
          _personContextSignal(
            now: harness.now,
            id: 'priority',
            kind: PersonContextKind.currentPriority,
            value: 'Release evidence',
          ),
        ],
      ),
    );
    await harness.notifier.stage(data: _taskData());

    final Completer<void> revisionGate = harness.repository
        .pauseNextGetAllTasks();
    final Future<CreatorHandshakeState> confirmation = harness.notifier
        .confirm();
    await Future<void>.delayed(Duration.zero);
    harness.setPersonContext(
      _personContextView(
        harness.now,
        signals: <PersonContextSignal>[
          _personContextSignal(
            now: harness.now,
            id: 'priority',
            kind: PersonContextKind.currentPriority,
            value: 'Pause release work',
          ),
        ],
      ),
    );
    revisionGate.complete();

    final CreatorHandshakeState stale = await confirmation;
    expect(stale.phase, CreatorHandshakePhase.stale);
    expect(stale.token, isNull);
    expect(harness.repository.saveCalls, 0);
  });

  test(
    'confirmed operation applies once and duplicate confirmation is inert',
    () async {
      final _Harness harness = _Harness();
      addTearDown(harness.dispose);
      await harness.notifier.stage(data: _taskData());

      final CreatorHandshakeState applied = await harness.notifier.confirm();
      final CreatorHandshakeState repeated = await harness.notifier.confirm();

      expect(applied.phase, CreatorHandshakePhase.applied);
      expect(repeated.phase, CreatorHandshakePhase.idempotent);
      expect(harness.repository.saveCalls, 1);
      expect(harness.repository.activeTasks, hasLength(1));
      expect(repeated.message, contains('No duplicate task'));
    },
  );

  test('confirmed scheduled task records first-run milestones', () async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);
    final AdaptiveGuidanceState initial = await harness.container.read(
      adaptiveGuidanceProvider.future,
    );
    expect(initial.has(GuidanceMilestone.firstItem), isFalse);
    expect(initial.has(GuidanceMilestone.firstSchedule), isFalse);

    await harness.notifier.stage(
      data: CreatorFormData(
        title: 'Put the first task on Timeline',
        type: 'Task',
        priority: 4,
        scheduledFor: harness.now.add(const Duration(hours: 2)),
      ),
    );
    final CreatorHandshakeState result = await harness.notifier.confirm();
    final AdaptiveGuidanceState guidance = await harness.container.read(
      adaptiveGuidanceProvider.future,
    );

    expect(result.phase, CreatorHandshakePhase.applied);
    expect(guidance.has(GuidanceMilestone.firstItem), isTrue);
    expect(guidance.has(GuidanceMilestone.firstSchedule), isTrue);
  });

  test(
    'durable ledger and deterministic task identity survive controller restart',
    () async {
      final _MemoryTaskRepository repository = _MemoryTaskRepository();
      final SecureStore store = SecureStore(
        backend: InMemorySecureStoreBackend(),
      );
      final DateTime fixedNow = DateTime.utc(2026, 8, 20, 18);

      final _Harness first = _Harness(
        repository: repository,
        store: store,
        now: fixedNow,
      );
      await first.notifier.stage(data: _taskData());
      await first.notifier.confirm();
      first.dispose();

      final _Harness restarted = _Harness(
        repository: repository,
        store: store,
        now: fixedNow,
      );
      addTearDown(restarted.dispose);
      await restarted.notifier.stage(data: _taskData());
      final CreatorHandshakeState replay = await restarted.notifier.confirm();

      expect(replay.phase, CreatorHandshakePhase.idempotent);
      expect(repository.saveCalls, 1);
      expect(repository.activeTasks, hasLength(1));
    },
  );

  test('changed domain version refreshes preview before any save', () async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);
    await harness.notifier.stage(data: _taskData());
    final String oldRevision = harness.state.preview!.baseDomainRevision;
    harness.repository.seed(
      TaskEntity(
        id: 'other-task',
        title: 'Concurrent task',
        createdAt: harness.now,
      ),
    );

    final CreatorHandshakeState stale = await harness.notifier.confirm();
    expect(stale.phase, CreatorHandshakePhase.stale);
    expect(stale.receipt, isNull);
    expect(stale.preview!.baseDomainRevision, isNot(oldRevision));
    expect(harness.repository.saveCalls, 0);

    final CreatorHandshakeState applied = await harness.notifier.confirm();
    expect(applied.phase, CreatorHandshakePhase.applied);
    expect(harness.repository.saveCalls, 1);
  });

  test(
    'expired confirmation refreshes and requires a second confirmation',
    () async {
      final _Harness harness = _Harness();
      addTearDown(harness.dispose);
      await harness.notifier.stage(data: _taskData());
      harness.now = harness.now.add(const Duration(minutes: 6));

      final CreatorHandshakeState expired = await harness.notifier.confirm();
      expect(expired.phase, CreatorHandshakePhase.expired);
      expect(expired.receipt, isNull);
      expect(harness.repository.saveCalls, 0);

      final CreatorHandshakeState applied = await harness.notifier.confirm();
      expect(applied.phase, CreatorHandshakePhase.applied);
      expect(harness.repository.saveCalls, 1);
    },
  );

  test(
    'undo removes only the unchanged confirmed task and is idempotent',
    () async {
      final _Harness harness = _Harness();
      addTearDown(harness.dispose);
      await harness.notifier.stage(data: _taskData());
      await harness.notifier.confirm();

      final CreatorHandshakeState undone = await harness.notifier.undo();
      final CreatorHandshakeState repeated = await harness.notifier.undo();

      expect(undone.phase, CreatorHandshakePhase.undone);
      expect(repeated.phase, CreatorHandshakePhase.undone);
      expect(harness.repository.deleteCalls, 1);
      expect(harness.repository.activeTasks, isEmpty);
    },
  );

  test(
    'undo is blocked if the created task changed after confirmation',
    () async {
      final _Harness harness = _Harness();
      addTearDown(harness.dispose);
      await harness.notifier.stage(data: _taskData());
      final CreatorHandshakeState applied = await harness.notifier.confirm();
      final String taskId = applied.receipt!.taskIds.single;
      harness.repository.seed(
        harness.repository.activeTasks.single.copyWith(
          id: taskId,
          title: 'User edited this after saving',
        ),
      );

      final CreatorHandshakeState blocked = await harness.notifier.undo();
      expect(blocked.phase, CreatorHandshakePhase.conflict);
      expect(harness.repository.deleteCalls, 0);
      expect(
        harness.repository.activeTasks.single.title,
        'User edited this after saving',
      );
    },
  );

  test('task mutation preserves all scheduling and goal fields', () async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);
    final DateTime scheduledFor = harness.now.add(const Duration(hours: 2));
    final DateTime dueDate = harness.now.add(const Duration(days: 2));
    await harness.notifier.stage(
      data: CreatorFormData(
        title: 'Prepare linked evidence',
        type: 'Task',
        priority: 4,
        goalId: 'goal-release',
        estimatedDuration: const Duration(minutes: 75),
        dueDate: dueDate,
        scheduledFor: scheduledFor,
        recurrenceRule: RecurrenceRule.weekly,
      ),
    );

    final CreatorHandshakeState applied = await harness.notifier.confirm();
    final TaskEntity task = harness.repository.activeTasks.single;
    expect(task.goalId, 'goal-release');
    expect(task.estimatedDuration, const Duration(minutes: 75));
    expect(task.dueDate, dueDate);
    expect(task.scheduledFor, scheduledFor);
    expect(task.recurrenceRule, RecurrenceRule.weekly);
    expect(applied.receipt!.taskIds, <String>[task.id]);
    expect(applied.receipt!.entityIds.single.kind, CreatorEntityKind.task);
  });

  test('Goal, Daily Rhythm, and Note persist as typed entities', () async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);
    final DateTime targetDate = harness.now.add(const Duration(days: 30));

    await harness.notifier.stage(
      data: CreatorFormData(
        title: 'Ship the evidence gate',
        description: 'A real outcome, not a task alias.',
        type: 'Goal',
        priority: 4,
        targetDate: targetDate,
      ),
    );
    final CreatorHandshakeState goalResult = await harness.notifier.confirm();
    final CreatorMutationOperation goalOperation =
        goalResult.preview!.selectedOperations.single;
    expect(harness.goalRepository.goals, hasLength(1));
    expect(harness.goalRepository.goals.single.targetDate, targetDate);
    expect(goalResult.receipt!.taskIds, isEmpty);
    expect(goalResult.receipt!.goalIds, hasLength(1));
    expect(goalResult.receipt!.entityIds.single.kind, CreatorEntityKind.goal);
    final String ledgerRaw = (await harness.store.readString(
      'creator_handshake_ledger_v1:${_testAccountScope.v2Namespace}',
    ))!;
    final Map<String, dynamic> ledger =
        jsonDecode(ledgerRaw) as Map<String, dynamic>;
    final Map<String, dynamic> ledgerEntry =
        ledger[goalOperation.operationId] as Map<String, dynamic>;
    expect(ledgerEntry['entityKind'], 'goal');
    expect(ledgerEntry['entityId'], goalOperation.entityId);
    expect(ledgerEntry['entityDigest'], goalOperation.entityDigest);

    harness.notifier.clearResult();
    await harness.notifier.stage(
      data: const CreatorFormData(
        title: 'Morning reset',
        description: 'A repeatable Daily Rhythm.',
        type: 'Daily Rhythm',
        priority: 2,
        recurrenceRule: RecurrenceRule.weekly,
        habitTargetCount: 3,
      ),
    );
    final CreatorMutationOperation habitOperation =
        harness.state.preview!.operations.single;
    expect(habitOperation.kind, CreatorMutationKind.createHabit);
    expect(habitOperation.label, 'Create daily rhythm');
    expect(habitOperation.task.recurrenceRule, RecurrenceRule.weekly);
    final CreatorHandshakeState habitResult = await harness.notifier.confirm();
    expect(harness.habitRepository.habits, hasLength(1));
    expect(harness.habitRepository.habits.single.cadence, HabitCadence.weekly);
    expect(harness.habitRepository.habits.single.targetCount, 3);
    expect(habitResult.receipt!.habitIds, hasLength(1));

    harness.notifier.clearResult();
    await harness.notifier.stage(
      data: const CreatorFormData(
        title: 'Decision context',
        description: 'Preserve the reviewed reason.',
        type: 'Note',
        priority: 1,
      ),
    );
    final CreatorHandshakeState noteResult = await harness.notifier.confirm();
    expect(harness.noteRepository.notes, hasLength(1));
    expect(
      harness.noteRepository.notes.single.body,
      'Preserve the reviewed reason.',
    );
    expect(noteResult.receipt!.noteIds, hasLength(1));
    expect(harness.repository.saveCalls, 0);
  });

  test('typed ledger prevents duplicate Daily Rhythm after restart', () async {
    final _MemoryTaskRepository tasks = _MemoryTaskRepository();
    final _MemoryGoalRepository goals = _MemoryGoalRepository();
    final _MemoryHabitRepository habits = _MemoryHabitRepository();
    final _MemoryNoteRepository notes = _MemoryNoteRepository();
    final SecureStore store = SecureStore(
      backend: InMemorySecureStoreBackend(),
    );
    final DateTime fixedNow = DateTime.utc(2026, 8, 20, 18);
    const CreatorFormData data = CreatorFormData(
      title: 'Evening reflection',
      type: 'Habit',
      priority: 2,
    );

    final _Harness first = _Harness(
      repository: tasks,
      goalRepository: goals,
      habitRepository: habits,
      noteRepository: notes,
      store: store,
      now: fixedNow,
    );
    await first.notifier.stage(data: data);
    await first.notifier.confirm();
    first.dispose();

    final _Harness restarted = _Harness(
      repository: tasks,
      goalRepository: goals,
      habitRepository: habits,
      noteRepository: notes,
      store: store,
      now: fixedNow,
    );
    addTearDown(restarted.dispose);
    await restarted.notifier.stage(data: data);
    final CreatorHandshakeState replay = await restarted.notifier.confirm();

    expect(replay.phase, CreatorHandshakePhase.idempotent);
    expect(habits.saveCalls, 1);
    expect(habits.habits, hasLength(1));
    expect(replay.receipt!.entityIds.single.kind, CreatorEntityKind.habit);
  });

  test(
    'domain revision detects Goal, Daily Rhythm, and Note changes',
    () async {
      Future<void> expectStaleAfter(
        void Function(_Harness harness) seed,
      ) async {
        final _Harness harness = _Harness();
        try {
          await harness.notifier.stage(data: _taskData());
          seed(harness);
          final CreatorHandshakeState result = await harness.notifier.confirm();
          expect(result.phase, CreatorHandshakePhase.stale);
          expect(result.receipt, isNull);
          expect(harness.repository.saveCalls, 0);
        } finally {
          harness.dispose();
        }
      }

      await expectStaleAfter(
        (_Harness harness) => harness.goalRepository.seed(
          GoalEntity(
            id: 'concurrent-goal',
            title: 'Concurrent goal',
            createdAt: harness.now,
          ),
        ),
      );
      await expectStaleAfter(
        (_Harness harness) => harness.habitRepository.seed(
          HabitEntity(
            id: 'concurrent-habit',
            title: 'Concurrent Daily Rhythm',
            createdAt: harness.now,
            updatedAt: harness.now,
          ),
        ),
      );
      await expectStaleAfter(
        (_Harness harness) => harness.noteRepository.seed(
          NoteEntity(
            id: 'concurrent-note',
            title: 'Concurrent note',
            createdAt: harness.now,
          ),
        ),
      );
    },
  );

  test('typed undo removes unchanged Goal, Daily Rhythm, and Note', () async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);

    await harness.notifier.stage(
      data: const CreatorFormData(
        title: 'Goal to undo',
        type: 'Goal',
        priority: 3,
      ),
    );
    await harness.notifier.confirm();
    expect((await harness.notifier.undo()).phase, CreatorHandshakePhase.undone);
    expect(harness.goalRepository.goals, isEmpty);

    harness.notifier.clearResult();
    await harness.notifier.stage(
      data: const CreatorFormData(
        title: 'Daily Rhythm to undo',
        type: 'Habit',
        priority: 3,
      ),
    );
    await harness.notifier.confirm();
    expect((await harness.notifier.undo()).phase, CreatorHandshakePhase.undone);
    expect(harness.habitRepository.habits, isEmpty);

    harness.notifier.clearResult();
    await harness.notifier.stage(
      data: const CreatorFormData(
        title: 'Note to undo',
        type: 'Note',
        priority: 1,
      ),
    );
    await harness.notifier.confirm();
    expect((await harness.notifier.undo()).phase, CreatorHandshakePhase.undone);
    expect(harness.noteRepository.notes, isEmpty);
    expect(harness.repository.deleteCalls, 0);
  });
}

CreatorFormData _taskData() => const CreatorFormData(
  title: 'Prepare release evidence',
  description: 'One bounded Creator mutation.',
  type: 'Task',
  priority: 4,
);

PersonContextView _personContextView(
  DateTime now, {
  List<PersonContextSignal> signals = const <PersonContextSignal>[],
}) {
  final Set<PersonContextKind> knownKinds = signals
      .map((PersonContextSignal signal) => signal.kind)
      .toSet();
  return PersonContextView(
    accountScopeId: _testAccountScope.v2Namespace!,
    surface: PersonContextSurface.creator,
    purposes: operationalPersonContextPurposes,
    observedAt: now,
    signals: signals,
    unknownKinds: PersonContextKind.values.toSet().difference(knownKinds),
  );
}

PersonContextSignal _personContextSignal({
  required DateTime now,
  required String id,
  required PersonContextKind kind,
  required String value,
}) => PersonContextSignal(
  id: id,
  kind: kind,
  value: value,
  source: PersonContextSource.userAuthored,
  consent: PersonContextConsent.granted,
  consentedAt: now.subtract(const Duration(hours: 1)),
  purpose: PersonContextPurpose.planningGuidance,
  surfaceScopes: const <PersonContextSurface>{PersonContextSurface.creator},
  recordedAt: now.subtract(const Duration(hours: 1)),
  freshUntil: now.add(const Duration(hours: 12)),
  expiresAt: now.add(const Duration(days: 1)),
  exportBehavior: PersonContextExportBehavior.include,
  deletionBehavior: PersonContextDeletionBehavior.userRemovable,
);

class _Harness {
  _Harness({
    _MemoryTaskRepository? repository,
    _MemoryGoalRepository? goalRepository,
    _MemoryHabitRepository? habitRepository,
    _MemoryNoteRepository? noteRepository,
    SecureStore? store,
    DateTime? now,
  }) : repository = repository ?? _MemoryTaskRepository(),
       goalRepository = goalRepository ?? _MemoryGoalRepository(),
       habitRepository = habitRepository ?? _MemoryHabitRepository(),
       noteRepository = noteRepository ?? _MemoryNoteRepository(),
       store = store ?? SecureStore(backend: InMemorySecureStoreBackend()),
       now = now ?? DateTime.utc(2026, 8, 20, 18) {
    container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(_testAccountScope),
        domainTaskRepositoryProvider.overrideWithValue(this.repository),
        domainGoalRepositoryProvider.overrideWithValue(this.goalRepository),
        domainHabitRepositoryProvider.overrideWithValue(this.habitRepository),
        domainNoteRepositoryProvider.overrideWithValue(this.noteRepository),
        secureStoreProvider.overrideWithValue(this.store),
        creatorHandshakeClockProvider.overrideWithValue(() => this.now),
        personContextForSurfaceProvider(
          _creatorPersonContextTestRequest,
        ).overrideWith((Ref ref) => ref.watch(_personContextTestProvider)),
      ],
    );
  }

  final _MemoryTaskRepository repository;
  final _MemoryGoalRepository goalRepository;
  final _MemoryHabitRepository habitRepository;
  final _MemoryNoteRepository noteRepository;
  final SecureStore store;
  late DateTime now;
  late final ProviderContainer container;

  CreatorHandshakeNotifier get notifier =>
      container.read(creatorHandshakeProvider.notifier);
  CreatorHandshakeState get state => container.read(creatorHandshakeProvider);
  PersonContextView? get creatorPersonContext => container.read(
    personContextForSurfaceProvider(_creatorPersonContextTestRequest),
  );

  void setPersonContext(PersonContextView? view) {
    container.read(_personContextTestProvider.notifier).set(view);
  }

  void dispose() => container.dispose();
}

final _personContextTestProvider =
    NotifierProvider<_PersonContextTestNotifier, PersonContextView?>(
      _PersonContextTestNotifier.new,
    );

final PersonContextAccessRequest _creatorPersonContextTestRequest =
    PersonContextAccessRequest(
      surface: PersonContextSurface.creator,
      purposes: operationalPersonContextPurposes,
    );

final AccountStorageScope _testAccountScope = AccountStorageScope.authenticated(
  'phase6-user',
);

class _PersonContextTestNotifier extends Notifier<PersonContextView?> {
  @override
  PersonContextView? build() => null;

  void set(PersonContextView? view) => state = view;
}

class _MemoryTaskRepository implements ITaskRepository {
  final Map<String, TaskEntity> _tasks = <String, TaskEntity>{};
  Completer<void>? _nextGetAllTasksGate;
  int saveCalls = 0;
  int deleteCalls = 0;

  List<TaskEntity> get activeTasks => _tasks.values
      .where((TaskEntity task) => !task.isCanceled)
      .toList(growable: false);

  void seed(TaskEntity task) => _tasks[task.id] = task;

  Completer<void> pauseNextGetAllTasks() {
    final Completer<void> gate = Completer<void>();
    _nextGetAllTasksGate = gate;
    return gate;
  }

  @override
  Future<void> deleteTask(String id) async {
    final TaskEntity? task = _tasks[id];
    if (task == null || task.isCanceled) return;
    deleteCalls += 1;
    _tasks[id] = task.copyWith(isCanceled: true, updatedAt: DateTime.now());
  }

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    final Completer<void>? gate = _nextGetAllTasksGate;
    _nextGetAllTasksGate = null;
    if (gate != null) await gate.future;
    return _tasks.values.toList(growable: false);
  }

  @override
  Future<TaskEntity?> getTaskById(String id) async {
    final TaskEntity? task = _tasks[id];
    return task == null || task.isCanceled ? null : task;
  }

  @override
  Future<void> saveTask(TaskEntity task) async {
    saveCalls += 1;
    _tasks[task.id] = task;
  }
}

class _MemoryGoalRepository implements IGoalRepository {
  final List<GoalEntity> goals = <GoalEntity>[];
  int saveCalls = 0;
  int deleteCalls = 0;

  void seed(GoalEntity goal) {
    goals.removeWhere((GoalEntity value) => value.id == goal.id);
    goals.add(goal);
  }

  @override
  Future<void> deleteGoal(String id) async {
    final int before = goals.length;
    goals.removeWhere((GoalEntity goal) => goal.id == id);
    if (goals.length != before) deleteCalls += 1;
  }

  @override
  List<GoalEntity> getGoals() => List<GoalEntity>.of(goals);

  @override
  Future<void> saveGoal(GoalEntity goal) async {
    saveCalls += 1;
    goals.removeWhere((GoalEntity value) => value.id == goal.id);
    goals.insert(0, goal);
  }

  @override
  Future<void> saveGoals(List<GoalEntity> values) async {
    saveCalls += 1;
    goals
      ..clear()
      ..addAll(values);
  }
}

class _MemoryHabitRepository implements IHabitRepository {
  final List<HabitEntity> habits = <HabitEntity>[];
  int saveCalls = 0;

  void seed(HabitEntity habit) {
    habits.removeWhere((HabitEntity value) => value.id == habit.id);
    habits.add(habit);
  }

  @override
  Future<List<HabitEntity>> getHabits() async => List<HabitEntity>.of(habits);

  @override
  Future<void> saveHabits(List<HabitEntity> values) async {
    saveCalls += 1;
    habits
      ..clear()
      ..addAll(values);
  }
}

class _MemoryNoteRepository implements INoteRepository {
  final List<NoteEntity> notes = <NoteEntity>[];
  int saveCalls = 0;
  int deleteCalls = 0;

  void seed(NoteEntity note) {
    notes.removeWhere((NoteEntity value) => value.id == note.id);
    notes.add(note);
  }

  @override
  Future<void> deleteNote(String id) async {
    final int before = notes.length;
    notes.removeWhere((NoteEntity note) => note.id == id);
    if (notes.length != before) deleteCalls += 1;
  }

  @override
  Future<List<NoteEntity>> getNotes() async => List<NoteEntity>.of(notes);

  @override
  Future<void> saveNote(NoteEntity note) async {
    saveCalls += 1;
    notes.removeWhere((NoteEntity value) => value.id == note.id);
    notes.insert(0, note);
  }
}
