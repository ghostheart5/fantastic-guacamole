import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/creator_handshake.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
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

  test('routine mapping is visible in preview before confirmation', () async {
    final _Harness harness = _Harness();
    addTearDown(harness.dispose);
    await harness.notifier.stage(
      data: const CreatorFormData(
        title: 'Morning reset',
        type: 'Routine',
        priority: 2,
      ),
    );

    final CreatorTaskMutation task =
        harness.state.preview!.operations.single.task;
    expect(task.recurrenceRule.name, 'daily');
    expect(task.energyRequired, 2);
    expect(task.priority, 2);
    expect(harness.repository.saveCalls, 0);
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
    SecureStore? store,
    DateTime? now,
  }) : repository = repository ?? _MemoryTaskRepository(),
       store = store ?? SecureStore(backend: InMemorySecureStoreBackend()),
       now = now ?? DateTime.utc(2026, 8, 20, 18) {
    container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(_testAccountScope),
        domainTaskRepositoryProvider.overrideWithValue(this.repository),
        secureStoreProvider.overrideWithValue(this.store),
        creatorHandshakeClockProvider.overrideWithValue(() => this.now),
        personContextForSurfaceProvider(
          _creatorPersonContextTestRequest,
        ).overrideWith((Ref ref) => ref.watch(_personContextTestProvider)),
      ],
    );
  }

  final _MemoryTaskRepository repository;
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
