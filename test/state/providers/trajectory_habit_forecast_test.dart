import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/habit_occurrence_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_decision_outcome_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/decision_outcome_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_engine_model_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_habit_provider.dart';
import 'package:fantastic_guacamole/state/services/habit_occurrence_coordinator.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/trajectory_live_container.dart';

/// Habits in the live forecast: their own projected lines, read the
/// account-safe way, live while watched, and changing nothing else. Fixed
/// local clock 2026-12-01 09:00; calendar fields only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final DateTime now = DateTime(2026, 12, 1, 9);
  DateTime daysAgo(int n) => DateTime(now.year, now.month, now.day - n, 9);

  HabitEntity habit(String id, String title) =>
      HabitEntity(id: id, title: title, createdAt: DateTime(2026, 9, 1, 8));

  HabitOccurrenceEntity record(HabitEntity h, DateTime at) =>
      HabitOccurrenceEntity(
        habitId: h.id,
        occurrenceKey: RhythmPlanningContext.occurrenceKey(h, at),
        operationId: 'op-${h.id}-${at.toIso8601String()}',
        outcome: HabitOccurrenceOutcome.completed,
        recordedAt: at.toUtc(),
      );

  late TrajectoryMemoryStore store;
  late Map<String, List<HabitEntity>> habitsByUser;

  Future<void> seed(String user, List<HabitOccurrenceEntity> records) =>
      HabitOccurrenceRepository(
        store,
        AccountStorageScope.authenticated(user),
      ).replaceSnapshot(records);

  ProviderContainer build({int completed7d = 7}) {
    final ProviderContainer container = trajectoryLiveContainer(
      now: now,
      clock: () => now.toUtc(),
      store: store,
      completed7d: completed7d,
      overrides: [
        authSessionBoundaryProvider.overrideWith(_Boundary.new),
        // The account follows the auth boundary like the real scope does.
        trajectoryLiveAccountProvider.overrideWith(_BoundaryAccount.new),
        secureStoreProvider.overrideWithValue(
          SecureStore(backend: InMemorySecureStoreBackend()),
        ),
        siStateProvider.overrideWith(_FixedSiStateController.new),
        learningProvider.overrideWith(_FixedLearningController.new),
        profileProvider.overrideWith(_TestProfileController.new),
        decisionOutcomeRepositoryProvider.overrideWithValue(null),
        domainHabitRepositoryProvider.overrideWith((Ref ref) {
          final AccountStorageScope scope = ref.watch(
            trajectoryLiveAccountProvider,
          );
          return _Habits(
            habitsByUser.putIfAbsent(scope.rawUserId ?? '', () => []),
          );
        }),
        habitOccurrenceCoordinatorProvider.overrideWith((Ref ref) {
          final AccountStorageScope scope = ref.watch(
            trajectoryLiveAccountProvider,
          );
          final HabitOccurrenceRepository? repository = ref.watch(
            habitOccurrenceRepositoryProvider,
          );
          if (repository == null) return null;
          return HabitOccurrenceCoordinator(
            scope: scope,
            habitRepository: ref.watch(domainHabitRepositoryProvider),
            occurrenceRepository: repository,
            outcomeRepository: _Outcomes(),
            learningPaused: () async => true,
            clock: () => now,
          );
        }),
        reminderOrchestratorServiceProvider.overrideWithValue(
          ReminderOrchestratorService(
            preferences: _DisabledPreferences(),
            notifications: NotificationsService(_NoopNotifications()),
            scheduler: NotificationScheduler(),
            accountScope: null,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(trajectoryConsequenceProvider, (_, _) {});
    return container;
  }

  /// The comparison once the account's habit lines have been read.
  Future<TrajectoryComparison> settled(ProviderContainer container) async {
    for (int i = 0; i < 500; i++) {
      final AsyncValue<TrajectoryHabitSource> source = container.read(
        trajectoryHabitSourceProvider,
      );
      final AsyncValue<TrajectoryComparison> c = container.read(
        trajectoryConsequenceProvider,
      );
      if (source.hasError) {
        Error.throwWithStackTrace(source.error!, source.stackTrace!);
      }
      if (source.hasValue && !source.isLoading && c.hasValue && !c.isLoading) {
        return c.requireValue;
      }
      await Future<void>.delayed(Duration.zero);
    }
    throw StateError('the comparison never settled');
  }

  setUp(() {
    store = TrajectoryMemoryStore();
    habitsByUser = <String, List<HabitEntity>>{
      'account-a': <HabitEntity>[habit('ha', 'Walk A')],
      'account-b': <HabitEntity>[habit('hb', 'Stretch B')],
    };
  });

  test('a daily habit done for 28 days is its own projected line', () async {
    await seed('account-a', <HabitOccurrenceEntity>[
      for (int i = 1; i <= 28; i++)
        record(habitsByUser['account-a']![0], daysAgo(i)),
    ]);
    final ProviderContainer container = build();
    final TrajectoryComparison c = await settled(container);
    final TrajectoryHabitNode line = c.baseline.habits.single;
    expect(line.habitId, 'ha');
    expect(line.title, 'Walk A');
    expect(line.expectedPeriods, 7);
    expect(line.projectedCheckIns!.mid, 7);
    expect(c.baseline.sourceRevisions['habits'], startsWith('1:'));
    for (final TrajectoryScenarioOutcome o in c.outcomes) {
      expect(
        o.evidence,
        contains('habit=ha:daily:enough:28/28:expected=7:check_ins=4-7-7'),
      );
    }

    container.read(trajectoryHorizonDaysProvider.notifier).select(30);
    final TrajectoryComparison thirty = await settled(container);
    expect(thirty.baseline.habits.single.expectedPeriods, 30);
    expect(thirty.baseline.habits.single.projectedCheckIns!.mid, 30);
  });

  group('habits change nothing else', () {
    for (final int range in <int>[7, 30, 90]) {
      test('range $range: every projected number, the ranking, the gate '
          'and the receipt are the same with and without habits', () async {
        final List<HabitEntity> mine = <HabitEntity>[
          habit('ha', 'Walk A'),
          habit('hr', 'Read'),
        ];
        await seed('account-a', <HabitOccurrenceEntity>[
          for (int i = 1; i <= 20; i++) record(mine[0], daysAgo(i)),
          for (int i = 1; i <= 5; i++) record(mine[1], daysAgo(i)),
        ]);

        habitsByUser['account-a'] = mine;
        final ProviderContainer withHabits = build();
        withHabits.read(trajectoryHorizonDaysProvider.notifier).select(range);
        final TrajectoryComparison a = await settled(withHabits);

        habitsByUser['account-a'] = <HabitEntity>[];
        final ProviderContainer without = build();
        without.read(trajectoryHorizonDaysProvider.notifier).select(range);
        final TrajectoryComparison b = await settled(without);

        expect(a.baseline.habits, hasLength(2));
        expect(b.baseline.habits, isEmpty);
        expect(b.baseline.sourceRevisions.containsKey('habits'), isFalse);
        expect(_baselineNumbers(a.baseline), _baselineNumbers(b.baseline));
        expect(
          a.outcomes.map(_outcomeNumbers).toList(),
          b.outcomes.map(_outcomeNumbers).toList(),
        );
        expect(
          _scenario(a.recommendedScenarioId),
          _scenario(b.recommendedScenarioId),
        );
        expect(trajectoryCanRecommend(a), trajectoryCanRecommend(b));
        expect(
          trajectoryHasMinimumEvidence(a),
          trajectoryHasMinimumEvidence(b),
        );
        // Evidence only gains the habit lines and the habit revision.
        for (int i = 0; i < a.outcomes.length; i++) {
          expect(
            _evidenceWithoutHabits(a.outcomes[i].evidence),
            _evidenceWithoutHabits(b.outcomes[i].evidence),
          );
          expect(
            a.outcomes[i].evidence.where((String e) => e.startsWith('habit=')),
            hasLength(2),
          );
        }
        // Receipts: same keys and values except the revision-derived ids; no
        // habit data is written.
        for (int i = 0; i < a.outcomes.length; i++) {
          final Map<String, dynamic> ra = _receiptJson(a, i, now);
          final Map<String, dynamic> rb = _receiptJson(b, i, now);
          expect(ra.keys.toList(), rb.keys.toList());
          expect(jsonEncode(ra).toLowerCase(), isNot(contains('habit')));
          for (final String key in <String>[
            'id',
            'baselineRevision',
            'scenarioId',
          ]) {
            ra.remove(key);
            rb.remove(key);
          }
          expect(jsonEncode(ra), jsonEncode(rb));
        }
      });
    }
  });

  test(
    'a check-in refreshes the lines and the revision while watched',
    () async {
      final HabitEntity walk = habitsByUser['account-a']![0];
      await seed('account-a', <HabitOccurrenceEntity>[
        for (int i = 2; i <= 10; i++) record(walk, daysAgo(i)),
      ]);
      final ProviderContainer container = build();
      final List<String> revisions = <String>[];
      container.listen(trajectoryConsequenceProvider, (_, next) {
        final TrajectoryComparison? c = next.value;
        if (c != null) revisions.add(c.baseline.revision);
      });
      final TrajectoryComparison before = await settled(container);
      expect(before.baseline.habits.single.completedPeriods, 9);
      expect(before.baseline.habits.single.checkedInThisPeriod, isFalse);
      await container.read(habitsProvider.future);

      // A check-in for yesterday, recorded through the habit list.
      await container
          .read(habitsProvider.notifier)
          .recordHabitAt('ha', daysAgo(1), completed: true);
      await pumpEventQueue();
      final TrajectoryComparison afterYesterday = await settled(container);
      expect(afterYesterday.baseline.habits.single.completedPeriods, 10);
      expect(
        afterYesterday.baseline.habits.single.projectedCheckIns!.mid,
        greaterThan(before.baseline.habits.single.projectedCheckIns!.mid),
      );
      expect(afterYesterday.baseline.revision, isNot(before.baseline.revision));

      // Today's check-in: the rate is unchanged, the line and revision are not.
      await container.read(habitsProvider.notifier).completeHabit('ha');
      await pumpEventQueue();
      final TrajectoryComparison afterToday = await settled(container);
      expect(afterToday.baseline.habits.single.checkedInThisPeriod, isTrue);
      expect(
        afterToday.baseline.revision,
        isNot(afterYesterday.baseline.revision),
      );
      expect(revisions.toSet(), hasLength(greaterThanOrEqualTo(3)));
    },
  );

  test('pausing a habit takes its line out', () async {
    final ProviderContainer container = build();
    expect((await settled(container)).baseline.habits, hasLength(1));
    await container.read(habitsProvider.future);
    await container.read(habitsProvider.notifier).toggleHabit('ha');
    await pumpEventQueue();
    final TrajectoryComparison after = await settled(container);
    expect(after.baseline.habits, isEmpty);
    expect(after.baseline.sourceRevisions.containsKey('habits'), isFalse);
  });

  test('after a real account switch no listener state holds the previous '
      'account\'s habit', () async {
    await seed('account-a', <HabitOccurrenceEntity>[
      for (int i = 1; i <= 5; i++)
        record(habitsByUser['account-a']![0], daysAgo(i)),
    ]);
    final ProviderContainer container = build();
    final _Boundary boundary =
        container.read(authSessionBoundaryProvider.notifier) as _Boundary;
    boundary.moveTo(
      const AuthSessionBoundary(
        generation: 2,
        userId: 'account-a',
        isTransitioning: false,
        isStorageReady: true,
      ),
    );
    final TrajectoryComparison a = await settled(container);
    expect(a.baseline.habits.map((TrajectoryHabitNode h) => h.title), <String>[
      'Walk A',
    ]);

    bool comparisonShowsA(AsyncValue<TrajectoryComparison> v) {
      final TrajectoryComparison? c = v.value;
      return c != null &&
          (c.baseline.habits.any(
                (TrajectoryHabitNode h) => h.habitId == 'ha',
              ) ||
              c.outcomes.any(
                (TrajectoryScenarioOutcome o) =>
                    o.evidence.any((String e) => e.startsWith('habit=ha:')),
              ));
    }

    bool sourceShowsA(AsyncValue<TrajectoryHabitSource> v) {
      final TrajectoryHabitSource? s = v.value;
      return s != null &&
          (s.habits.any((HabitEntity h) => h.id == 'ha') ||
              s.occurrences.any(
                (HabitOccurrenceEntity o) => o.habitId == 'ha',
              ));
    }

    final List<AsyncValue<TrajectoryComparison>> seen =
        <AsyncValue<TrajectoryComparison>>[];
    final List<AsyncValue<TrajectoryHabitSource>> seenSource =
        <AsyncValue<TrajectoryHabitSource>>[];
    container.listen(
      trajectoryConsequenceProvider,
      (_, next) => seen.add(next),
    );
    container.listen(
      trajectoryHabitSourceProvider,
      (_, next) => seenSource.add(next),
    );
    final List<AsyncValue<TrajectoryComparison>> reads =
        <AsyncValue<TrajectoryComparison>>[];
    final List<AsyncValue<TrajectoryHabitSource>> sourceReads =
        <AsyncValue<TrajectoryHabitSource>>[];
    // The same steps as a real sign-out and sign-in as B (the fence
    // invalidates the habit list), reading what a screen would read after
    // each one. The habit source is not invalidated here, so the test does
    // not rely on the fence for it.
    void move(AuthSessionBoundary next) {
      boundary.moveTo(next);
      container.invalidate(habitsProvider);
      reads.add(container.read(trajectoryConsequenceProvider));
      sourceReads.add(container.read(trajectoryHabitSourceProvider));
    }

    move(
      const AuthSessionBoundary(
        generation: 3,
        userId: 'account-b',
        isTransitioning: true,
        isStorageReady: false,
      ),
    );
    move(
      const AuthSessionBoundary(
        generation: 4,
        userId: 'account-b',
        isTransitioning: false,
        isStorageReady: true,
      ),
    );
    final TrajectoryComparison b = await settled(container);
    await pumpEventQueue();
    reads.add(container.read(trajectoryConsequenceProvider));
    sourceReads.add(container.read(trajectoryHabitSourceProvider));

    expect(b.baseline.habits.map((TrajectoryHabitNode h) => h.title), <String>[
      'Stretch B',
    ]);
    expect(seen, isNotEmpty);
    expect(seenSource, isNotEmpty);
    expect(seen.where(comparisonShowsA), isEmpty);
    expect(reads.where(comparisonShowsA), isEmpty);
    expect(seenSource.where(sourceShowsA), isEmpty);
    expect(sourceReads.where(sourceShowsA), isEmpty);
  });

  test('a source of another account is never used', () {
    final TrajectoryHabitEvidenceView view = trajectoryHabitEvidence(
      source: AsyncData<TrajectoryHabitSource>(
        TrajectoryHabitSource(
          namespace: 'v2.other',
          habits: <HabitEntity>[habit('ha', 'Walk A')],
          occurrences: const <HabitOccurrenceEntity>[],
        ),
      ),
      namespace: 'v2.mine',
      now: now,
      horizonDays: 7,
    );
    expect(view.nodes, isEmpty);
    expect(view.revision, isNull);
  });

  test(
    '2 observed outcomes plus ten habit check-ins is still learning',
    () async {
      await seed('account-a', <HabitOccurrenceEntity>[
        for (int i = 1; i <= 10; i++)
          record(habitsByUser['account-a']![0], daysAgo(i)),
      ]);
      final ProviderContainer container = build(completed7d: 2);
      final TrajectoryComparison c = await settled(container);
      expect(c.baseline.habits.single.completedPeriods, 10);
      expect(c.baseline.observationCount, 2);
      expect(trajectoryHasMinimumEvidence(c), isFalse);
      expect(trajectoryCanRecommend(c), isFalse);
      final TrajectoryEngineModel model = container.read(
        trajectoryEngineModelProvider,
      );
      expect(trajectoryMinimumObservedOutcomes, 3);
      expect(model.status, TrajectoryEngineStatus.learning);
      // Nothing is recorded below the minimum.
      expect(
        store.values.keys.where(
          (String k) => k.startsWith('chronospark.trajectory.forecast_ledger'),
        ),
        isEmpty,
      );
    },
  );
}

String _scenario(String id) => id.substring(id.indexOf(':') + 1);

List<String> _evidenceWithoutHabits(List<String> evidence) => evidence
    .where(
      (String e) =>
          !e.startsWith('habit=') &&
          !e.startsWith('habits=') &&
          !e.startsWith('baseline_revision='),
    )
    .toList();

List<Object?> _baselineNumbers(TrajectoryBaseline b) => <Object?>[
  b.momentum,
  b.pressure,
  b.pressureInHorizon,
  b.energy,
  b.completedInWindow,
  b.deferredInWindow,
  b.observationCount,
  b.availableMinutes,
  b.occupiedMinutes,
  b.unscheduledMinutes,
  b.dailyFreeMinutes,
  b.dailyFreeOrigin,
  b.tasksInHorizon,
  b.requiredMinutesInHorizon,
  b.expectedCompletionsInHorizon.low,
  b.expectedCompletionsInHorizon.mid,
  b.expectedCompletionsInHorizon.high,
  b.horizonDays,
  b.confidence.band,
  b.assumptions,
  b.tasks.map((TrajectoryTaskNode t) => t.id).toList(),
];

List<Object?> _outcomeNumbers(TrajectoryScenarioOutcome o) => <Object?>[
  o.intervention.id,
  o.projectedMomentum,
  o.projectedPressure,
  o.uncertainty,
  o.confidence.band,
  o.confidence.calibration,
  o.risk.currentScore,
  o.risk.projectedScore,
  o.risk.band,
  o.risk.contributions
      .map(
        (TrajectoryRiskContribution r) =>
            '${r.code}:${r.currentScore}:${r.projectedScore}:${r.isScored}',
      )
      .toList(),
  o.timeline.deadlineCrossings,
  o.timeline.minutesAdded,
  o.timeline.displacedSubjectIds,
  o.goals
      .map(
        (GoalDelayProjection g) =>
            '${g.goalId}:${g.delayDays}:${g.remainingMinutes}:'
            '${g.projectedCompletion.toIso8601String()}',
      )
      .toList(),
  o.progression.potentialXp,
  o.utilityScore,
  o.assumptions,
  o.modelVersion,
];

Map<String, dynamic> _receiptJson(
  TrajectoryComparison c,
  int index,
  DateTime now,
) =>
    jsonDecode(
          jsonEncode(
            TrajectoryForecastReceipt.fromScenario(
              baseline: c.baseline,
              outcome: c.outcomes[index],
              selectedAt: now.toUtc(),
            ).toJson(),
          ),
        )
        as Map<String, dynamic>;

class _Boundary extends AuthSessionBoundaryNotifier {
  @override
  AuthSessionBoundary build() => const AuthSessionBoundary(
    generation: 1,
    userId: 'account-a',
    isTransitioning: false,
    isStorageReady: true,
  );

  void moveTo(AuthSessionBoundary next) => state = next;
}

class _BoundaryAccount extends TrajectoryLiveAccount {
  @override
  AccountStorageScope build() {
    final AuthSessionBoundary b = ref.watch(authSessionBoundaryProvider);
    return b.userId != null && b.isStorageReady && !b.isTransitioning
        ? AccountStorageScope.authenticated(b.userId!)
        : const AccountStorageScope.unsafe();
  }
}

class _FixedSiStateController extends SIStateController {
  @override
  SIState build() =>
      const SIState(energy: 0.8, fatigue: 0.1, completedToday: 0);
}

class _FixedLearningController extends LearningController {
  @override
  LearningState build() => const LearningState();
}

class _TestProfileController extends ProfileController {
  @override
  ProfileState build() => ProfileState();

  @override
  Future<void> addXP(int amount) async {
    state = state.copyWith(xp: state.xp + amount);
  }
}

class _Habits implements IHabitRepository {
  _Habits(this._records);
  final List<HabitEntity> _records;

  @override
  Future<List<HabitEntity>> getHabits() async => List<HabitEntity>.of(_records);

  @override
  Future<void> saveHabits(List<HabitEntity> habits) async {
    _records
      ..clear()
      ..addAll(habits);
  }
}

class _Outcomes implements IDecisionOutcomeRepository {
  @override
  Future<List<DecisionOutcomeEntity>> load() async =>
      const <DecisionOutcomeEntity>[];

  @override
  Future<void> record(DecisionOutcomeEntity outcome) async {}
}

final class _DisabledPreferences implements SharedPrefsStore {
  @override
  Future<void> clear() async {}
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> init() async {}
  @override
  String? load(String key) => 'false';
  @override
  Future<void> save(String key, String value) async {}
}

final class _NoopNotifications implements INotificationRepository {
  @override
  Future<void> cancelNotification(String id) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<List<NotificationEntity>> getNotifications() async =>
      const <NotificationEntity>[];
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {}
}
