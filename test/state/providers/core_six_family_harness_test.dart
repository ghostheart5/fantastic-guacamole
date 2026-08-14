import 'dart:io';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/repositories/habit_repository.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/domain/entities/completion_event_entity.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/plan_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/completion_events_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/timeline_misc_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _HiveStore implements HiveStore {
  const _HiveStore();

  static final List<String> accesses = <String>[];

  @override
  Box<T> box<T>(String key) {
    accesses.add('box:$key');
    return Hive.box<dynamic>(key) as Box<T>;
  }
  @override
  Future<void> clearBox(String key) async => Hive.box<dynamic>(key).clear();
  @override
  Future<void> closeBox(String key) async => Hive.box<dynamic>(key).close();
  @override
  Future<void> init() async {}
  @override
  bool isBoxOpen(String key) => Hive.isBoxOpen(key);
  @override
  Future<Box<T>> openBox<T>(String key) async {
    accesses.add('open:$key');
    return (await Hive.openBox<dynamic>(key)) as Box<T>;
  }
}

class _Prefs implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};
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

class _ScopeDriver {
  _ScopeDriver(this.scope);

  AccountStorageScope scope;
}

enum _Family { task, goal, habit, timeline, completion }

int _diagnosticScopeSequence = 0;

final _drivenScopeProvider = Provider<AccountStorageScope>(
  (Ref ref) => const AccountStorageScope.unsafe(),
);

ProviderContainer _container(_ScopeDriver driver, _Prefs prefs) =>
    ProviderContainer(overrides: [
      _drivenScopeProvider.overrideWith((Ref ref) => driver.scope),
      accountStorageScopeProvider.overrideWith(
        (Ref ref) => ref.watch(_drivenScopeProvider),
      ),
      hiveStoreProvider.overrideWithValue(const _HiveStore()),
      sensitivePrefsStoreProvider.overrideWithValue(prefs),
    ]);

void _invalidateForAccountHandoff(ProviderContainer container) {
  container.invalidate(_drivenScopeProvider);
  container.invalidate(accountStorageScopeProvider);
  container.invalidate(taskRepositoryProvider);
  container.invalidate(goalRepositoryProvider);
  container.invalidate(domainTaskRepositoryProvider);
  container.invalidate(domainGoalRepositoryProvider);
  container.invalidate(getTasksUseCaseProvider);
  container.invalidate(getGoalsUseCaseProvider);
  container.invalidate(createTaskUseCaseProvider);
  container.invalidate(completeTaskUseCaseProvider);
  container.invalidate(updateTaskUseCaseProvider);
  container.invalidate(featureCreateGoalUseCaseProvider);
  container.invalidate(featureUpdateGoalUseCaseProvider);
  container.invalidate(deleteGoalUseCaseProvider);
  container.invalidate(completeGoalUseCaseProvider);
  container.invalidate(habitRepositoryProvider);
  container.invalidate(planRepositoryProvider);
  container.invalidate(domainPlanRepositoryProvider);
  container.invalidate(getPlanUseCaseProvider);
  container.invalidate(createPlanUseCaseProvider);
  container.invalidate(updatePlanUseCaseProvider);
  container.invalidate(timelineRepositoryProvider);
  container.invalidate(viewTimelineUsecaseProvider);
  container.invalidate(completionEventRepositoryProvider);
}

Future<void> _openScopeBoxes(AccountStorageScope scope) async {
  final String goals = HiveBoxes.accountScoped(HiveBoxes.goals, scope);
  if (!Hive.isBoxOpen(goals)) await Hive.openBox<dynamic>(goals);
}

Future<void> _seed(ProviderContainer container, String owner) async {
  final DateTime now = DateTime.utc(2026, 8, 13);
  await container.read(taskRepositoryProvider).saveTask(
    TaskEntity(id: '${owner}_ONLY_TASK', title: '${owner}_ONLY_TASK', createdAt: now),
  );
  await container.read(taskRepositoryProvider).saveTask(
    TaskEntity(id: 'SHARED_TASK', title: '${owner}_TASK_VALUE', createdAt: now),
  );
  await container.read(goalRepositoryProvider).saveGoal(
    GoalEntity(id: '${owner}_ONLY_GOAL', title: '${owner}_ONLY_GOAL', createdAt: now),
  );
  await container.read(goalRepositoryProvider).saveGoal(
    GoalEntity(id: 'SHARED_GOAL', title: '${owner}_GOAL_VALUE', createdAt: now),
  );
  await container.read(habitRepositoryProvider).saveHabits(<HabitRecord>[
    HabitRecord(id: '${owner}_ONLY_HABIT', title: '${owner}_ONLY_HABIT', createdAt: now),
  ]);
  await container.read(planRepositoryProvider).savePlan(
    PlanEntity(id: '${owner}_ONLY_PLAN', date: now, blocks: const []),
  );
  await container.read(timelineRepositoryProvider).addEvent(
    TimelineEventEntity(
      id: '${owner}_ONLY_TIMELINE',
      type: TimelineEventType.task,
      title: '${owner}_ONLY_TIMELINE',
      detail: '',
      timestamp: now,
    ),
  );
  await container.read(completionEventRepositoryProvider).addEvent(
    CompletionEventEntity(
      id: '${owner}_ONLY_COMPLETION',
      taskId: '${owner}_ONLY_TASK',
      eventType: CompletionEventType.completed,
      eventAt: now,
    ),
  );
}

Future<void> _expectOnlyOwner(ProviderContainer container, String owner) async {
  expect(
    (await container.read(taskRepositoryProvider).getAllTasks())
        .any((TaskEntity item) => item.id == '${owner}_ONLY_TASK'),
    isTrue,
  );
  expect(
    (await container.read(domainTaskRepositoryProvider).getAllTasks())
        .any((TaskEntity item) => item.id == '${owner}_ONLY_TASK'),
    isTrue,
  );
  expect(
    container.read(goalRepositoryProvider).getGoals().any(
      (GoalEntity item) => item.id == '${owner}_ONLY_GOAL',
    ),
    isTrue,
  );
  expect(
    container.read(domainGoalRepositoryProvider).getGoals().any(
      (GoalEntity item) => item.id == '${owner}_ONLY_GOAL',
    ),
    isTrue,
  );
  expect(
    (await container.read(habitRepositoryProvider).getHabits()).single.id,
    '${owner}_ONLY_HABIT',
  );
  expect((await container.read(planRepositoryProvider).getPlan(DateTime.utc(2026, 8, 13)))!.id, '${owner}_ONLY_PLAN');
  expect(container.read(timelineRepositoryProvider).getEvents().single.id, '${owner}_ONLY_TIMELINE');
  expect(container.read(viewTimelineUsecaseProvider)().single.id, '${owner}_ONLY_TIMELINE');
  expect(container.read(completionEventRepositoryProvider).getEvents().single.id, '${owner}_ONLY_COMPLETION');
}

Future<void> _expectOwnerAbsent(ProviderContainer container, String owner) async {
  expect((await container.read(taskRepositoryProvider).getAllTasks()).where((TaskEntity item) => item.id == '${owner}_ONLY_TASK'), isEmpty);
  expect(container.read(goalRepositoryProvider).getGoals().where((GoalEntity item) => item.id == '${owner}_ONLY_GOAL'), isEmpty);
  expect((await container.read(habitRepositoryProvider).getHabits()).where((HabitRecord item) => item.id == '${owner}_ONLY_HABIT'), isEmpty);
  final planRepository = container.read(planRepositoryProvider);
  final domainPlanRepository = container.read(domainPlanRepositoryProvider);
  final getPlan = container.read(getPlanUseCaseProvider);
  final DateTime date = DateTime.utc(2026, 8, 13);
  _HiveStore.accesses.clear();
  final PlanEntity? repositoryResult = await planRepository.getPlan(date);
  final List<String> repositoryAccesses = List<String>.of(_HiveStore.accesses);
  final PlanEntity? domainResult = await domainPlanRepository.getPlan(date);
  final PlanEntity? useCaseResult = await getPlan(date);
  // This is the exact original assertion expression, evaluated fresh.
  final PlanEntity? originalAssertionResult = await container
      .read(planRepositoryProvider)
      .getPlan(date);
  // ignore: avoid_print
  print(
    'A4-01B-DIAG-04 owner=$owner '
    'repo=${repositoryResult?.id} domain=${domainResult?.id} '
    'usecase=${useCaseResult?.id} original=${originalAssertionResult?.id}',
  );
  // ignore: avoid_print
  print('A4-01B-DIAG-04 owner=$owner storage=$repositoryAccesses');
  // Plans are keyed by date. On B→A, A's same-date plan must remain readable;
  // the isolation assertion is that the other account's plan ID is absent.
  expect(originalAssertionResult?.id, isNot('${owner}_ONLY_PLAN'));
  expect(container.read(timelineRepositoryProvider).getEvents().where((TimelineEventEntity item) => item.id == '${owner}_ONLY_TIMELINE'), isEmpty);
  expect(container.read(completionEventRepositoryProvider).getEvents().where((CompletionEventEntity item) => item.id == '${owner}_ONLY_COMPLETION'), isEmpty);
}

Future<void> _transition(
  ProviderContainer container,
  _ScopeDriver driver,
  AccountStorageScope target,
) async {
  driver.scope = const AccountStorageScope.unsafe();
  _invalidateForAccountHandoff(container);
  expect(container.read(accountStorageScopeProvider).v2Namespace, isNull);
  driver.scope = target;
  _invalidateForAccountHandoff(container);
  if (target.v2Namespace != null) await _openScopeBoxes(target);
}

Future<void> _expectUnsafeWritesFail(ProviderContainer container) async {
  final DateTime now = DateTime.utc(2026, 8, 14);
  await expectLater(
    container.read(taskRepositoryProvider).saveTask(
      TaskEntity(id: 'UNSAFE_TASK', title: 'unsafe', createdAt: now),
    ),
    throwsA(isA<Object>()),
  );
  await expectLater(
    container.read(goalRepositoryProvider).saveGoal(
      GoalEntity(id: 'UNSAFE_GOAL', title: 'unsafe', createdAt: now),
    ),
    throwsA(isA<Object>()),
  );
  await expectLater(
    container.read(habitRepositoryProvider).saveHabits(<HabitRecord>[
      HabitRecord(id: 'UNSAFE_HABIT', title: 'unsafe', createdAt: now),
    ]),
    throwsA(isA<Object>()),
  );
  await expectLater(
    container.read(planRepositoryProvider).savePlan(
      PlanEntity(id: 'UNSAFE_PLAN', date: now, blocks: const []),
    ),
    throwsA(isA<Object>()),
  );
  expect(
    () => container.read(timelineRepositoryProvider).addEvent(
      TimelineEventEntity(
        id: 'UNSAFE_TIMELINE',
        type: TimelineEventType.task,
        title: 'unsafe',
        detail: '',
        timestamp: now,
      ),
    ),
    throwsStateError,
  );
  expect(
    () => container.read(completionEventRepositoryProvider).addEvent(
      CompletionEventEntity(
        id: 'UNSAFE_COMPLETION',
        taskId: 'UNSAFE_TASK',
        eventType: CompletionEventType.completed,
        eventAt: now,
      ),
    ),
    throwsStateError,
  );
}

Future<(bool rawEmpty, bool planFirstNull, bool planAfterReadsNull, bool domainNull, bool useCaseNull)> _probePlan(
  String label,
  Set<_Family> families,
  {bool readPlanFirst = true, bool includeShared = false}
) async {
  final _Prefs prefs = _Prefs();
  final _ScopeDriver driver = _ScopeDriver(AccountStorageScope.authenticated('$label-a'));
  final ProviderContainer container = _container(driver, prefs);
  final DateTime date = DateTime.utc(2026, 8, 13);
  try {
    await _openScopeBoxes(driver.scope);
    await container.read(planRepositoryProvider).savePlan(PlanEntity(id: 'A_PLAN', date: date, blocks: const []));
    if (families.contains(_Family.task)) await container.read(taskRepositoryProvider).saveTask(TaskEntity(id: 'A_TASK', title: 'A', createdAt: date));
    if (includeShared && families.contains(_Family.task)) await container.read(taskRepositoryProvider).saveTask(TaskEntity(id: 'SHARED_TASK', title: 'A_SHARED', createdAt: date));
    if (families.contains(_Family.goal)) await container.read(goalRepositoryProvider).saveGoal(GoalEntity(id: 'A_GOAL', title: 'A', createdAt: date));
    if (includeShared && families.contains(_Family.goal)) await container.read(goalRepositoryProvider).saveGoal(GoalEntity(id: 'SHARED_GOAL', title: 'A_SHARED', createdAt: date));
    if (families.contains(_Family.habit)) await container.read(habitRepositoryProvider).saveHabits(<HabitRecord>[HabitRecord(id: 'A_HABIT', title: 'A', createdAt: date)]);
    if (families.contains(_Family.timeline)) await container.read(timelineRepositoryProvider).addEvent(TimelineEventEntity(id: 'A_TIMELINE', type: TimelineEventType.task, title: 'A', detail: '', timestamp: date));
    if (families.contains(_Family.completion)) await container.read(completionEventRepositoryProvider).addEvent(CompletionEventEntity(id: 'A_COMPLETION', taskId: 'A_TASK', eventType: CompletionEventType.completed, eventAt: date));
    driver.scope = const AccountStorageScope.unsafe();
    _invalidateForAccountHandoff(container);
    driver.scope = AccountStorageScope.authenticated('$label-b');
    _invalidateForAccountHandoff(container);
    await _openScopeBoxes(driver.scope);
    final String box = HiveBoxes.accountScoped(HiveBoxes.dailyPlans, driver.scope);
    if (!Hive.isBoxOpen(box)) await Hive.openBox<dynamic>(box);
    final bool rawEmpty = Hive.box<dynamic>(box).get('2026-08-13') == null;
    final bool planFirstNull = !readPlanFirst || await container.read(planRepositoryProvider).getPlan(date) == null;
    if (families.contains(_Family.task)) await container.read(taskRepositoryProvider).getAllTasks();
    if (families.contains(_Family.goal)) container.read(goalRepositoryProvider).getGoals();
    if (families.contains(_Family.habit)) await container.read(habitRepositoryProvider).getHabits();
    if (families.contains(_Family.timeline)) container.read(timelineRepositoryProvider).getEvents();
    if (families.contains(_Family.completion)) container.read(completionEventRepositoryProvider).getEvents();
    return (rawEmpty, planFirstNull, await container.read(planRepositoryProvider).getPlan(date) == null, await container.read(domainPlanRepositoryProvider).getPlan(date) == null, await container.read(getPlanUseCaseProvider)(date) == null);
  } finally { container.dispose(); }
}

Future<(bool rawEmpty, bool repositoryNull, bool domainNull, bool useCaseNull)> _probeOriginalOperations({
  required bool captureAGraph,
  required bool readUnsafe,
  bool captureBGraph = false,
  Set<_Family> bAbsenceReads = const <_Family>{},
  bool retainAndCompare = false,
  bool matcherUnsafeAssertions = false,
  bool originalRawSequence = false,
}) async {
  final _Prefs prefs = _Prefs();
  final String scopePrefix = 'diag-operation-${_diagnosticScopeSequence++}';
  final String aUser = '$scopePrefix-a';
  final String bUser = '$scopePrefix-b';
  final _ScopeDriver driver = _ScopeDriver(AccountStorageScope.authenticated(aUser));
  final ProviderContainer container = _container(driver, prefs);
  final DateTime date = DateTime.utc(2026, 8, 13);
  try {
    await _openScopeBoxes(driver.scope);
    await _seed(container, 'A');
    await _expectOnlyOwner(container, 'A');
    final List<Object> retainedA = <Object>[];
    if (captureAGraph) {
      retainedA.addAll(<Object>[
        container.read(taskRepositoryProvider), container.read(domainTaskRepositoryProvider),
        container.read(goalRepositoryProvider), container.read(domainGoalRepositoryProvider),
        container.read(habitRepositoryProvider), container.read(planRepositoryProvider),
        container.read(domainPlanRepositoryProvider), container.read(getPlanUseCaseProvider),
        container.read(timelineRepositoryProvider), container.read(viewTimelineUsecaseProvider),
        container.read(completionEventRepositoryProvider),
      ]);
    }
    driver.scope = const AccountStorageScope.unsafe();
    _invalidateForAccountHandoff(container);
    if (readUnsafe) {
      if (matcherUnsafeAssertions) {
        await expectLater(container.read(taskRepositoryProvider).getAllTasks(), throwsA(isNotNull));
        expect(() => container.read(timelineRepositoryProvider).getEvents(), throwsStateError);
      } else {
        await container.read(taskRepositoryProvider).getAllTasks().catchError((Object _) => <TaskEntity>[]);
        try {
          container.read(timelineRepositoryProvider).getEvents();
        } on Object {
          // Unsafe Timeline storage is the expected test result.
        }
      }
    }
    driver.scope = AccountStorageScope.authenticated(bUser);
    _invalidateForAccountHandoff(container);
    await _openScopeBoxes(driver.scope);
    if (originalRawSequence) {
      expect(container.read(accountStorageScopeProvider).rawUserId, bUser);
      final String aBox = HiveBoxes.accountScoped(HiveBoxes.dailyPlans, AccountStorageScope.authenticated(aUser));
      final String bBox = HiveBoxes.accountScoped(HiveBoxes.dailyPlans, driver.scope);
      expect(aBox, isNot(bBox));
      if (!Hive.isBoxOpen(bBox)) await Hive.openBox<dynamic>(bBox);
      expect(Hive.box<dynamic>(bBox).get('2026-08-13'), isNull);
    }
    if (captureBGraph) {
      final List<Object> bGraph = <Object>[
        container.read(taskRepositoryProvider), container.read(domainTaskRepositoryProvider),
        container.read(goalRepositoryProvider), container.read(domainGoalRepositoryProvider),
        container.read(habitRepositoryProvider), container.read(planRepositoryProvider),
        container.read(timelineRepositoryProvider), container.read(viewTimelineUsecaseProvider),
        container.read(completionEventRepositoryProvider),
      ];
      if (retainAndCompare) {
        for (int index = 0; index < retainedA.length && index < bGraph.length; index++) {
          identical(retainedA[index], bGraph[index]);
        }
      }
    }
    if (bAbsenceReads.contains(_Family.task)) {
      expect((await container.read(taskRepositoryProvider).getAllTasks()).where((TaskEntity item) => item.id == 'A_ONLY_TASK'), isEmpty);
    }
    if (bAbsenceReads.contains(_Family.goal)) {
      expect(container.read(goalRepositoryProvider).getGoals().where((GoalEntity item) => item.id == 'A_ONLY_GOAL'), isEmpty);
    }
    if (bAbsenceReads.contains(_Family.habit)) {
      expect((await container.read(habitRepositoryProvider).getHabits()).where((HabitRecord item) => item.id == 'A_ONLY_HABIT'), isEmpty);
    }
    final String box = HiveBoxes.accountScoped(HiveBoxes.dailyPlans, driver.scope);
    if (!Hive.isBoxOpen(box)) await Hive.openBox<dynamic>(box);
    return (
      Hive.box<dynamic>(box).get('2026-08-13') == null,
      await container.read(planRepositoryProvider).getPlan(date) == null,
      await container.read(domainPlanRepositoryProvider).getPlan(date) == null,
      await container.read(getPlanUseCaseProvider)(date) == null,
    );
  } finally { container.dispose(); }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => Hive.init(Directory.systemTemp.createTempSync('a4-harness-').path));

  test('A4-01 six-family A-to-B-to-A handoff recreates providers without global fallback', () async {
    final _Prefs prefs = _Prefs();
    final _ScopeDriver driver = _ScopeDriver(AccountStorageScope.authenticated('a4-a'));
    final ProviderContainer container = _container(driver, prefs);
    addTearDown(container.dispose);

    await _openScopeBoxes(driver.scope);
    await _seed(container, 'A');
    await _expectOnlyOwner(container, 'A');

    final Object taskA = container.read(taskRepositoryProvider);
    final Object domainTaskA = container.read(domainTaskRepositoryProvider);
    final Object goalA = container.read(goalRepositoryProvider);
    final Object domainGoalA = container.read(domainGoalRepositoryProvider);
    final Object habitA = container.read(habitRepositoryProvider);
    final Object planA = container.read(planRepositoryProvider);
    final Object timelineA = container.read(timelineRepositoryProvider);
    final Object viewTimelineA = container.read(viewTimelineUsecaseProvider);
    final Object completionA = container.read(completionEventRepositoryProvider);

    driver.scope = const AccountStorageScope.unsafe();
    _invalidateForAccountHandoff(container);
    expect(container.read(accountStorageScopeProvider).v2Namespace, isNull);
    await expectLater(container.read(taskRepositoryProvider).getAllTasks(), throwsA(isNotNull));
    expect(() => container.read(timelineRepositoryProvider).getEvents(), throwsStateError);

    driver.scope = AccountStorageScope.authenticated('a4-b');
    _invalidateForAccountHandoff(container);
    await _openScopeBoxes(driver.scope);
    expect(container.read(accountStorageScopeProvider).rawUserId, 'a4-b');
    expect(identical(planA, container.read(planRepositoryProvider)), isFalse);
    final String aPlanBox = HiveBoxes.accountScoped(
      HiveBoxes.dailyPlans,
      AccountStorageScope.authenticated('a4-a'),
    );
    final String bPlanBox = HiveBoxes.accountScoped(HiveBoxes.dailyPlans, driver.scope);
    expect(aPlanBox, isNot(bPlanBox));
    if (!Hive.isBoxOpen(bPlanBox)) await Hive.openBox<dynamic>(bPlanBox);
    expect(Hive.box<dynamic>(bPlanBox).get('2026-08-13'), isNull);
    await _expectOwnerAbsent(container, 'A');

    expect(identical(taskA, container.read(taskRepositoryProvider)), isFalse);
    expect(identical(domainTaskA, container.read(domainTaskRepositoryProvider)), isFalse);
    expect(identical(goalA, container.read(goalRepositoryProvider)), isFalse);
    expect(identical(domainGoalA, container.read(domainGoalRepositoryProvider)), isFalse);
    expect(identical(habitA, container.read(habitRepositoryProvider)), isFalse);
    expect(identical(timelineA, container.read(timelineRepositoryProvider)), isFalse);
    expect(identical(viewTimelineA, container.read(viewTimelineUsecaseProvider)), isFalse);
    expect(identical(completionA, container.read(completionEventRepositoryProvider)), isFalse);

    await _seed(container, 'B');
    await _expectOnlyOwner(container, 'B');

    driver.scope = const AccountStorageScope.unsafe();
    _invalidateForAccountHandoff(container);
    driver.scope = AccountStorageScope.authenticated('a4-a');
    _invalidateForAccountHandoff(container);
    await _openScopeBoxes(driver.scope);
    await _expectOnlyOwner(container, 'A');
    await _expectOwnerAbsent(container, 'B');

    final TaskEntity sharedTask = (await container.read(taskRepositoryProvider).getAllTasks())
        .singleWhere((TaskEntity item) => item.id == 'SHARED_TASK');
    final GoalEntity sharedGoal = container.read(goalRepositoryProvider).getGoals()
        .singleWhere((GoalEntity item) => item.id == 'SHARED_GOAL');
    expect(sharedTask.title, 'A_TASK_VALUE');
    expect(sharedGoal.title, 'A_GOAL_VALUE');
    expect(prefs.values.keys, everyElement(contains('.v2.')));
  });

  test('A4-01B diagnosis: Plan-only current lifecycle invalidations bind B reads to B storage', () async {
    final _Prefs prefs = _Prefs();
    final _ScopeDriver driver = _ScopeDriver(AccountStorageScope.authenticated('plan-a'));
    final ProviderContainer container = _container(driver, prefs);
    addTearDown(container.dispose);
    final DateTime date = DateTime.utc(2026, 8, 13);

    await _openScopeBoxes(driver.scope);
    await container.read(planRepositoryProvider).savePlan(
      PlanEntity(id: 'A_PLAN', date: date, blocks: const []),
    );
    final Object planA = container.read(planRepositoryProvider);
    expect((await container.read(planRepositoryProvider).getPlan(date))!.id, 'A_PLAN');

    driver.scope = const AccountStorageScope.unsafe();
    _invalidateForAccountHandoff(container);
    driver.scope = AccountStorageScope.authenticated('plan-b');
    _invalidateForAccountHandoff(container);

    final String bBox = HiveBoxes.accountScoped(HiveBoxes.dailyPlans, driver.scope);
    if (!Hive.isBoxOpen(bBox)) await Hive.openBox<dynamic>(bBox);
    expect(Hive.box<dynamic>(bBox).get('2026-08-13'), isNull);
    final Object planB = container.read(planRepositoryProvider);
    expect(identical(planA, planB), isFalse);
    expect(await container.read(planRepositoryProvider).getPlan(date), isNull);
    expect(await container.read(domainPlanRepositoryProvider).getPlan(date), isNull);
    expect(await container.read(getPlanUseCaseProvider)(date), isNull);
  });

  test('A4-01B DIAG-02: mixed-family Plan delta matrix', () async {
    final Map<String, Set<_Family>> rows = <String, Set<_Family>>{
      'task': <_Family>{_Family.task}, 'goal': <_Family>{_Family.goal}, 'habit': <_Family>{_Family.habit},
      'task-goal': <_Family>{_Family.task, _Family.goal}, 'task-habit': <_Family>{_Family.task, _Family.habit},
      'goal-habit': <_Family>{_Family.goal, _Family.habit}, 'core': <_Family>{_Family.task, _Family.goal, _Family.habit},
      'timeline': <_Family>{_Family.task, _Family.goal, _Family.habit, _Family.timeline},
      'completion': <_Family>{_Family.task, _Family.goal, _Family.habit, _Family.timeline, _Family.completion},
    };
    for (final MapEntry<String, Set<_Family>> row in rows.entries) {
      final result = await _probePlan('diag-${row.key}', row.value);
      final delayed = await _probePlan('diag-delayed-${row.key}', row.value, readPlanFirst: false);
      // ignore: avoid_print
      print('A4-01B-DIAG-02 ${row.key}: raw=${result.$1} first=${result.$2} after=${result.$3} domain=${result.$4} usecase=${result.$5}');
      // ignore: avoid_print
      print('A4-01B-DIAG-02 delayed-${row.key}: raw=${delayed.$1} after=${delayed.$3} domain=${delayed.$4} usecase=${delayed.$5}');
      expect(result.$1, isTrue, reason: row.key);
      expect(delayed.$1, isTrue, reason: 'delayed-${row.key}');
    }
    final exact = await _probePlan('a4-matrix', rows['completion']!, readPlanFirst: false);
    // ignore: avoid_print
    print('A4-01B-DIAG-02 exact-a4: raw=${exact.$1} after=${exact.$3} domain=${exact.$4} usecase=${exact.$5}');
    expect(exact.$1, isTrue);
    final shared = await _probePlan('a4-shared', rows['completion']!, readPlanFirst: false, includeShared: true);
    // ignore: avoid_print
    print('A4-01B-DIAG-02 shared: raw=${shared.$1} after=${shared.$3} domain=${shared.$4} usecase=${shared.$5}');
    expect(shared.$1, isTrue);
  });

  test('A4-01B DIAG-03: original-only operation differential', () async {
    for (final ({bool capture, bool unsafe, bool bGraph}) variant in <({bool capture, bool unsafe, bool bGraph})>[
      (capture: true, unsafe: false, bGraph: false), (capture: false, unsafe: true, bGraph: false),
      (capture: true, unsafe: true, bGraph: false), (capture: true, unsafe: true, bGraph: true),
    ]) {
      final result = await _probeOriginalOperations(captureAGraph: variant.capture, readUnsafe: variant.unsafe, captureBGraph: variant.bGraph);
      // ignore: avoid_print
      print('A4-01B-DIAG-03 capture=${variant.capture} unsafe=${variant.unsafe} bGraph=${variant.bGraph}: raw=${result.$1} repo=${result.$2} domain=${result.$3} usecase=${result.$4}');
      expect(result.$1, isTrue);
    }
  });

  test('A4-01B DIAG-03: B-absence helper differential', () async {
    final Map<String, Set<_Family>> reads = <String, Set<_Family>>{
      'task': <_Family>{_Family.task}, 'goal': <_Family>{_Family.goal}, 'habit': <_Family>{_Family.habit},
      'all': <_Family>{_Family.task, _Family.goal, _Family.habit},
    };
    for (final MapEntry<String, Set<_Family>> row in reads.entries) {
      final result = await _probeOriginalOperations(captureAGraph: true, readUnsafe: true, captureBGraph: true, bAbsenceReads: row.value);
      // ignore: avoid_print
      print('A4-01B-DIAG-03 absence-${row.key}: raw=${result.$1} repo=${result.$2} domain=${result.$3} usecase=${result.$4}');
      expect(result.$1, isTrue);
    }
  });

  test('A4-01B DIAG-03: retained A graph identity comparison', () async {
    final result = await _probeOriginalOperations(
      captureAGraph: true,
      readUnsafe: true,
      captureBGraph: true,
      bAbsenceReads: <_Family>{_Family.task, _Family.goal, _Family.habit},
      retainAndCompare: true,
    );
    // ignore: avoid_print
    print('A4-01B-DIAG-03 retained: raw=${result.$1} repo=${result.$2} domain=${result.$3} usecase=${result.$4}');
    expect(result.$1, isTrue);
  });

  test('A4-01B DIAG-03: matcher-based unsafe assertion differential', () async {
    final result = await _probeOriginalOperations(
      captureAGraph: true, readUnsafe: true, captureBGraph: true,
      bAbsenceReads: <_Family>{_Family.task, _Family.goal, _Family.habit},
      retainAndCompare: true, matcherUnsafeAssertions: true,
      originalRawSequence: true,
    );
    // ignore: avoid_print
    print('A4-01B-DIAG-03 matcher-unsafe: raw=${result.$1} repo=${result.$2} domain=${result.$3} usecase=${result.$4}');
    expect(result.$1, isTrue);
  });

  test('A4-02 same-user refresh preserves six-family A storage and read chains', () async {
    final _Prefs prefs = _Prefs();
    final _ScopeDriver driver = _ScopeDriver(AccountStorageScope.authenticated('a4-refresh-a'));
    final ProviderContainer container = _container(driver, prefs);
    addTearDown(container.dispose);

    await _openScopeBoxes(driver.scope);
    await _seed(container, 'A_REFRESH');
    final String namespace = container.read(accountStorageScopeProvider).v2Namespace!;
    final String taskBox = HiveBoxes.accountScoped(HiveBoxes.tasks, driver.scope);

    // A refresh is permitted to recreate provider instances, but never to
    // select a different namespace or claim an unscoped legacy store.
    _invalidateForAccountHandoff(container);
    expect(container.read(accountStorageScopeProvider).isAuthenticated, isTrue);
    expect(container.read(accountStorageScopeProvider).v2Namespace, namespace);
    expect(HiveBoxes.accountScoped(HiveBoxes.tasks, driver.scope), taskBox);
    await _expectOnlyOwner(container, 'A_REFRESH');
    expect((await container.read(taskRepositoryProvider).getAllTasks()).where((TaskEntity item) => item.id == 'A_REFRESH_ONLY_TASK'), hasLength(1));
    expect(container.read(goalRepositoryProvider).getGoals().where((GoalEntity item) => item.id == 'A_REFRESH_ONLY_GOAL'), hasLength(1));
    expect(prefs.values.keys.where((String key) => key.endsWith('_v1')), isEmpty);
  });

  test('A4-02 A-to-signed-out-to-B-to-A preserves isolated V2 data', () async {
    final _Prefs prefs = _Prefs();
    final _ScopeDriver driver = _ScopeDriver(AccountStorageScope.authenticated('a4-signout-a'));
    final ProviderContainer container = _container(driver, prefs);
    addTearDown(container.dispose);

    await _openScopeBoxes(driver.scope);
    await _seed(container, 'A_SIGNOUT');
    final String aNamespace = driver.scope.v2Namespace!;

    await _transition(container, driver, const AccountStorageScope.signedOut());
    expect(container.read(accountStorageScopeProvider).isAuthenticated, isFalse);
    expect(container.read(accountStorageScopeProvider).v2Namespace, 'v2.signed_out');
    await _expectOwnerAbsent(container, 'A_SIGNOUT');
    expect(prefs.values.keys.where((String key) => key.contains(aNamespace)).isNotEmpty, isTrue);
    expect(prefs.values.keys.where((String key) => key.endsWith('_v1')), isEmpty);

    await _transition(container, driver, AccountStorageScope.authenticated('a4-signout-b'));
    await _expectOwnerAbsent(container, 'A_SIGNOUT');
    await _seed(container, 'B_SIGNOUT');
    await _expectOnlyOwner(container, 'B_SIGNOUT');

    await _transition(container, driver, AccountStorageScope.authenticated('a4-signout-a'));
    await _expectOnlyOwner(container, 'A_SIGNOUT');
    await _expectOwnerAbsent(container, 'B_SIGNOUT');
  });

  test('A4-02 superseded A-to-B-to-C transition binds only the final target', () async {
    final _Prefs prefs = _Prefs();
    final _ScopeDriver driver = _ScopeDriver(AccountStorageScope.authenticated('a4-rapid-a'));
    final ProviderContainer container = _container(driver, prefs);
    addTearDown(container.dispose);

    await _openScopeBoxes(driver.scope);
    await _seed(container, 'A_RAPID');
    final List<Object> aGraph = <Object>[
      container.read(taskRepositoryProvider), container.read(domainTaskRepositoryProvider),
      container.read(goalRepositoryProvider), container.read(domainGoalRepositoryProvider),
      container.read(habitRepositoryProvider), container.read(planRepositoryProvider),
      container.read(getPlanUseCaseProvider), container.read(timelineRepositoryProvider),
      container.read(viewTimelineUsecaseProvider), container.read(completionEventRepositoryProvider),
    ];

    // This is the strongest harness-supported supersession: B never reaches
    // an authenticated-ready scope before the final C target replaces it.
    final ProviderContainer boundaryContainer = ProviderContainer();
    addTearDown(boundaryContainer.dispose);
    final AuthSessionBoundaryNotifier boundary = boundaryContainer.read(
      authSessionBoundaryProvider.notifier,
    );
    final int bGeneration = boundary.begin(userId: 'a4-rapid-b', isTransitioning: true);
    final int cGeneration = boundary.begin(userId: 'a4-rapid-c', isTransitioning: true);
    boundary.complete(bGeneration); // Superseded generation cannot become ready.
    boundary.complete(cGeneration);
    final AccountStorageScope boundaryScope = resolveAccountStorageScope(
      user: const User(id: 'a4-rapid-c', emailVerified: true),
      boundary: boundaryContainer.read(authSessionBoundaryProvider),
    );
    expect(boundaryContainer.read(authSessionBoundaryProvider).userId, 'a4-rapid-c');
    expect(boundaryScope.rawUserId, 'a4-rapid-c');
    expect(boundaryScope.v2Namespace, 'v2.YTQtcmFwaWQtYw==');
    driver.scope = const AccountStorageScope.unsafe();
    _invalidateForAccountHandoff(container);
    await _expectUnsafeWritesFail(container);
    driver.scope = AccountStorageScope.authenticated('a4-rapid-c');
    _invalidateForAccountHandoff(container);
    await _openScopeBoxes(driver.scope);

    expect(container.read(accountStorageScopeProvider).rawUserId, 'a4-rapid-c');
    expect(container.read(accountStorageScopeProvider).v2Namespace, 'v2.YTQtcmFwaWQtYw==');
    await _expectOwnerAbsent(container, 'A_RAPID');
    await _seed(container, 'FINAL_RAPID');
    await _expectOnlyOwner(container, 'FINAL_RAPID');
    final List<Object> finalGraph = <Object>[
      container.read(taskRepositoryProvider), container.read(domainTaskRepositoryProvider),
      container.read(goalRepositoryProvider), container.read(domainGoalRepositoryProvider),
      container.read(habitRepositoryProvider), container.read(planRepositoryProvider),
      container.read(getPlanUseCaseProvider), container.read(timelineRepositoryProvider),
      container.read(viewTimelineUsecaseProvider), container.read(completionEventRepositoryProvider),
    ];
    for (int index = 0; index < aGraph.length; index++) {
      expect(identical(aGraph[index], finalGraph[index]), isFalse);
    }
    expect(prefs.values.keys.where((String key) => key.endsWith('_v1')), isEmpty);
  });

  test('A4-02 transition writes fail closed or remain bound to A, never B', () async {
    final _Prefs prefs = _Prefs();
    final _ScopeDriver driver = _ScopeDriver(AccountStorageScope.authenticated('a4-write-a'));
    final ProviderContainer container = _container(driver, prefs);
    addTearDown(container.dispose);
    final DateTime now = DateTime.utc(2026, 8, 14);

    await _openScopeBoxes(driver.scope);
    final taskA = container.read(taskRepositoryProvider);
    final goalA = container.read(goalRepositoryProvider);
    final habitA = container.read(habitRepositoryProvider);
    final planA = container.read(planRepositoryProvider);
    final timelineA = container.read(timelineRepositoryProvider);
    final completionA = container.read(completionEventRepositoryProvider);

    driver.scope = const AccountStorageScope.unsafe();
    _invalidateForAccountHandoff(container);
    await expectLater(taskA.saveTask(TaskEntity(id: 'A_TRANSITION_TASK', title: 'A', createdAt: now)), throwsA(isA<Object>()));
    await expectLater(goalA.saveGoal(GoalEntity(id: 'A_TRANSITION_GOAL', title: 'A', createdAt: now)), throwsA(isA<Object>()));
    await expectLater(habitA.saveHabits(<HabitRecord>[HabitRecord(id: 'A_TRANSITION_HABIT', title: 'A', createdAt: now)]), throwsA(isA<Object>()));
    await expectLater(planA.savePlan(PlanEntity(id: 'A_TRANSITION_PLAN', date: now, blocks: const [])), throwsA(isA<Object>()));
    await timelineA.addEvent(TimelineEventEntity(id: 'A_TRANSITION_TIMELINE', type: TimelineEventType.task, title: 'A', detail: '', timestamp: now));
    await completionA.addEvent(CompletionEventEntity(id: 'A_TRANSITION_COMPLETION', taskId: 'A_TRANSITION_TASK', eventType: CompletionEventType.completed, eventAt: now));
    await _expectUnsafeWritesFail(container);

    driver.scope = AccountStorageScope.authenticated('a4-write-b');
    _invalidateForAccountHandoff(container);
    await _openScopeBoxes(driver.scope);
    expect((await container.read(taskRepositoryProvider).getAllTasks()).where((TaskEntity item) => item.id == 'A_TRANSITION_TASK'), isEmpty);
    expect(container.read(goalRepositoryProvider).getGoals().where((GoalEntity item) => item.id == 'A_TRANSITION_GOAL'), isEmpty);
    expect((await container.read(habitRepositoryProvider).getHabits()).where((HabitRecord item) => item.id == 'A_TRANSITION_HABIT'), isEmpty);
    expect(await container.read(planRepositoryProvider).getPlan(now), isNull);
    expect(container.read(timelineRepositoryProvider).getEvents().where((TimelineEventEntity item) => item.id == 'A_TRANSITION_TIMELINE'), isEmpty);
    expect(container.read(completionEventRepositoryProvider).getEvents().where((CompletionEventEntity item) => item.id == 'A_TRANSITION_COMPLETION'), isEmpty);

    await _transition(container, driver, AccountStorageScope.authenticated('a4-write-a'));
    expect(container.read(timelineRepositoryProvider).getEvents().where((TimelineEventEntity item) => item.id == 'A_TRANSITION_TIMELINE'), hasLength(1));
    expect(container.read(completionEventRepositoryProvider).getEvents().where((CompletionEventEntity item) => item.id == 'A_TRANSITION_COMPLETION'), hasLength(1));
  });

  test('A4-03 SI direct context and Timeline/Completion read paths bind to the current account', () async {
    final _Prefs prefs = _Prefs();
    final _ScopeDriver driver = _ScopeDriver(AccountStorageScope.authenticated('a4-context-a'));
    final ProviderContainer container = _container(driver, prefs);
    addTearDown(container.dispose);
    final DateTime date = DateTime.utc(2026, 8, 13);

    await _openScopeBoxes(driver.scope);
    await _seed(container, 'A_CTX');
    final dependenciesA = container.read(siEngineDependenciesProvider);
    expect((await dependenciesA.tasks.getAllTasks()).any((TaskEntity item) => item.id == 'A_CTX_ONLY_TASK'), isTrue);
    expect(dependenciesA.goals.getGoals().any((GoalEntity item) => item.id == 'A_CTX_ONLY_GOAL'), isTrue);
    expect((await dependenciesA.plan.getPlan(date))!.id, 'A_CTX_ONLY_PLAN');
    expect(dependenciesA.timeline.getEvents().single.id, 'A_CTX_ONLY_TIMELINE');
    expect(container.read(timelineProvider).single.id, 'A_CTX_ONLY_TIMELINE');
    expect(container.read(completionEventsProvider).single.id, 'A_CTX_ONLY_COMPLETION');

    await _transition(container, driver, AccountStorageScope.authenticated('a4-context-b'));
    container.invalidate(siEngineDependenciesProvider);
    container.invalidate(timelineProvider);
    container.invalidate(completionEventsProvider);
    final dependenciesB = container.read(siEngineDependenciesProvider);
    expect((await dependenciesB.tasks.getAllTasks()).where((TaskEntity item) => item.id.startsWith('A_CTX_')), isEmpty);
    expect(dependenciesB.goals.getGoals().where((GoalEntity item) => item.id.startsWith('A_CTX_')), isEmpty);
    expect(await dependenciesB.plan.getPlan(date), isNull);
    expect(dependenciesB.timeline.getEvents().where((TimelineEventEntity item) => item.id.startsWith('A_CTX_')), isEmpty);
    expect(container.read(timelineProvider).where((TimelineEventEntity item) => item.id.startsWith('A_CTX_')), isEmpty);
    expect(container.read(completionEventsProvider).where((CompletionEventEntity item) => item.id.startsWith('A_CTX_')), isEmpty);

    await _seed(container, 'B_CTX');
    container.invalidate(timelineProvider);
    container.invalidate(completionEventsProvider);
    expect((await dependenciesB.tasks.getAllTasks()).any((TaskEntity item) => item.id == 'B_CTX_ONLY_TASK'), isTrue);
    expect(dependenciesB.goals.getGoals().any((GoalEntity item) => item.id == 'B_CTX_ONLY_GOAL'), isTrue);
    expect((await dependenciesB.plan.getPlan(date))!.id, 'B_CTX_ONLY_PLAN');
    expect(dependenciesB.timeline.getEvents().single.id, 'B_CTX_ONLY_TIMELINE');
    expect(container.read(timelineProvider).single.id, 'B_CTX_ONLY_TIMELINE');
    expect(container.read(completionEventsProvider).single.id, 'B_CTX_ONLY_COMPLETION');
  });

  test('A4-03 six B mutations remain in B V2 storage and A restores unchanged', () async {
    final _Prefs prefs = _Prefs();
    final _ScopeDriver driver = _ScopeDriver(AccountStorageScope.authenticated('a4-mutation-a'));
    final ProviderContainer container = _container(driver, prefs);
    addTearDown(container.dispose);
    final DateTime date = DateTime.utc(2026, 8, 15);

    await _openScopeBoxes(driver.scope);
    await _seed(container, 'A_MUTATION');
    await _transition(container, driver, AccountStorageScope.authenticated('a4-mutation-b'));
    await container.read(taskRepositoryProvider).saveTask(TaskEntity(id: 'B_MUTATION_TASK', title: 'B mutation task', createdAt: date));
    await container.read(goalRepositoryProvider).saveGoal(GoalEntity(id: 'B_MUTATION_GOAL', title: 'B mutation goal', createdAt: date));
    await container.read(habitRepositoryProvider).saveHabits(<HabitRecord>[HabitRecord(id: 'B_MUTATION_HABIT', title: 'B mutation habit', createdAt: date)]);
    await container.read(planRepositoryProvider).savePlan(PlanEntity(id: 'B_MUTATION_PLAN', date: date, blocks: const []));
    await container.read(timelineRepositoryProvider).addEvent(TimelineEventEntity(id: 'B_MUTATION_TIMELINE', type: TimelineEventType.task, title: 'B mutation timeline', detail: '', timestamp: date));
    await container.read(completionEventRepositoryProvider).addEvent(CompletionEventEntity(id: 'B_MUTATION_COMPLETION', taskId: 'B_MUTATION_TASK', eventType: CompletionEventType.completed, eventAt: date));

    expect((await container.read(taskRepositoryProvider).getAllTasks()).any((TaskEntity item) => item.id == 'B_MUTATION_TASK'), isTrue);
    expect(container.read(goalRepositoryProvider).getGoals().any((GoalEntity item) => item.id == 'B_MUTATION_GOAL'), isTrue);
    expect((await container.read(habitRepositoryProvider).getHabits()).single.id, 'B_MUTATION_HABIT');
    expect((await container.read(planRepositoryProvider).getPlan(date))!.id, 'B_MUTATION_PLAN');
    expect(container.read(timelineRepositoryProvider).getEvents().single.id, 'B_MUTATION_TIMELINE');
    expect(container.read(completionEventRepositoryProvider).getEvents().single.id, 'B_MUTATION_COMPLETION');

    await _transition(container, driver, AccountStorageScope.authenticated('a4-mutation-a'));
    await _expectOnlyOwner(container, 'A_MUTATION');
    expect((await container.read(taskRepositoryProvider).getAllTasks()).where((TaskEntity item) => item.id == 'B_MUTATION_TASK'), isEmpty);
    expect(container.read(goalRepositoryProvider).getGoals().where((GoalEntity item) => item.id == 'B_MUTATION_GOAL'), isEmpty);
    expect((await container.read(habitRepositoryProvider).getHabits()).where((HabitRecord item) => item.id == 'B_MUTATION_HABIT'), isEmpty);
    expect(await container.read(planRepositoryProvider).getPlan(date), isNull);
    expect(container.read(timelineRepositoryProvider).getEvents().where((TimelineEventEntity item) => item.id == 'B_MUTATION_TIMELINE'), isEmpty);
    expect(container.read(completionEventRepositoryProvider).getEvents().where((CompletionEventEntity item) => item.id == 'B_MUTATION_COMPLETION'), isEmpty);
    expect(prefs.values.keys.where((String key) => key.endsWith('_v1')), isEmpty);
  });

  test('A4-04 B destructive operations are account-local and preserve A and V1', () async {
    final _Prefs prefs = _Prefs()
      ..values['timeline_events_v1'] = 'legacy-timeline'
      ..values['completion_events_v1'] = 'legacy-completion';
    final _ScopeDriver driver = _ScopeDriver(AccountStorageScope.authenticated('a4-delete-a'));
    final ProviderContainer container = _container(driver, prefs);
    addTearDown(container.dispose);
    final DateTime date = DateTime.utc(2026, 8, 16);

    await _openScopeBoxes(driver.scope);
    await _seed(container, 'A_DELETE');
    await container.read(planRepositoryProvider).savePlan(PlanEntity(id: 'A_DELETE_SAME_DATE', date: date, blocks: const []));
    await _transition(container, driver, AccountStorageScope.authenticated('a4-delete-b'));
    await _seed(container, 'B_DELETE');
    await container.read(planRepositoryProvider).savePlan(PlanEntity(id: 'B_DELETE_SAME_DATE', date: date, blocks: const []));

    await container.read(taskRepositoryProvider).deleteTask('B_DELETE_ONLY_TASK');
    await container.read(goalRepositoryProvider).deleteGoal('B_DELETE_ONLY_GOAL');
    await container.read(habitRepositoryProvider).saveHabits(const <HabitRecord>[]);
    // PlanRepository offers replacement-by-date, not an ordinary delete/clear.
    await container.read(planRepositoryProvider).savePlan(PlanEntity(id: 'B_DELETE_REPLACED', date: date, blocks: const []));
    await container.read(timelineRepositoryProvider).removeEvent('B_DELETE_ONLY_TIMELINE');
    await container.read(completionEventRepositoryProvider).removeEvent('B_DELETE_ONLY_COMPLETION');

    expect((await container.read(taskRepositoryProvider).getAllTasks()).where((TaskEntity item) => item.id == 'B_DELETE_ONLY_TASK'), isEmpty);
    expect(container.read(goalRepositoryProvider).getGoals().where((GoalEntity item) => item.id == 'B_DELETE_ONLY_GOAL'), isEmpty);
    expect(await container.read(habitRepositoryProvider).getHabits(), isEmpty);
    expect((await container.read(planRepositoryProvider).getPlan(date))!.id, 'B_DELETE_REPLACED');
    expect(container.read(timelineRepositoryProvider).getEvents().where((TimelineEventEntity item) => item.id == 'B_DELETE_ONLY_TIMELINE'), isEmpty);
    expect(container.read(completionEventRepositoryProvider).getEvents().where((CompletionEventEntity item) => item.id == 'B_DELETE_ONLY_COMPLETION'), isEmpty);
    expect(prefs.values['timeline_events_v1'], 'legacy-timeline');
    expect(prefs.values['completion_events_v1'], 'legacy-completion');

    await _transition(container, driver, AccountStorageScope.authenticated('a4-delete-a'));
    await _expectOnlyOwner(container, 'A_DELETE');
    expect((await container.read(planRepositoryProvider).getPlan(date))!.id, 'A_DELETE_SAME_DATE');
    expect(prefs.values['timeline_events_v1'], 'legacy-timeline');
    expect(prefs.values['completion_events_v1'], 'legacy-completion');
  });

}
