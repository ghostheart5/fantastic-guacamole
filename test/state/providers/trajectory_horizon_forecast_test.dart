import 'dart:convert';

import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/work_window_entity.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/planning/planner_input.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:fantastic_guacamole/engine/decision/decision_engine.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/models/progression_state.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/models/signal_model.dart';
import 'package:fantastic_guacamole/state/models/signals_models.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/operating_system_provider.dart';
import 'package:fantastic_guacamole/state/providers/person_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/progression_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_engine_model_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/trajectory_test_fixture.dart';

/// Model v4: the time range decides which tasks count, and workload is
/// measured against free time. Every fixture uses local calendar fields and a
/// fixed clock.
void main() {
  final DateTime now = DateTime(2026, 12, 1, 9);
  DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);

  // Task A 60 min due on day 5, task B 120 min due on day 40, task C 30 min
  // with no date (the brief's fixture).
  List<Task> briefTasks() => <Task>[
    _task('task-a', 60, dueDate: day(5)),
    _task('task-b', 120, dueDate: day(40)),
    _task('task-c', 30),
  ];

  group('the time range decides which tasks count', () {
    test('7 days: A and C, 90 minutes, about 2 expected done', () async {
      final TrajectoryBaseline b = (await _compare(
        briefTasks(),
        now: now,
        horizonDays: 7,
      )).baseline;
      expect(b.horizonDays, 7);
      expect(b.dailyFreeMinutes, 240);
      expect(b.dailyFreeOrigin, PredictiveEvidenceOrigin.observed);
      expect(b.tasksInHorizon, 2);
      expect(b.requiredMinutesInHorizon, 90);
      expect(b.expectedCompletionsInHorizon.mid, 2);
      // ceil(sqrt(2)) = 2 either side, kept within 0..tasks in the range.
      expect(b.expectedCompletionsInHorizon.low, 0);
      expect(b.expectedCompletionsInHorizon.high, 2);
    });

    test('90 days: all three, 210 minutes, about 3 expected done', () async {
      final TrajectoryBaseline b = (await _compare(
        briefTasks(),
        now: now,
        horizonDays: 90,
      )).baseline;
      expect(b.horizonDays, 90);
      expect(b.tasksInHorizon, 3);
      expect(b.requiredMinutesInHorizon, 210);
      expect(b.expectedCompletionsInHorizon.mid, 3);
      expect(b.expectedCompletionsInHorizon.low, 1);
      expect(b.expectedCompletionsInHorizon.high, 3);
    });

    test('expected completions follow the 7-day pace and its range', () async {
      final List<Task> many = <Task>[
        for (int i = 0; i < 40; i++) _task('t$i', 15),
      ];
      final TrajectoryBaseline b = (await _compare(
        many,
        now: now,
        horizonDays: 30,
        completed7d: 3,
      )).baseline;
      // round(3 / 7 x 30) = round(12.86) = 13; ceil(sqrt(13)) = 4.
      expect(b.expectedCompletionsInHorizon.mid, 13);
      expect(b.expectedCompletionsInHorizon.low, 9);
      expect(b.expectedCompletionsInHorizon.high, 17);
    });

    test('undated tasks count in every range and that is stated', () async {
      final TrajectoryBaseline b = (await _compare(
        briefTasks(),
        now: now,
        horizonDays: 7,
      )).baseline;
      expect(
        b.assumptions,
        contains('Tasks without a date are counted in every time range.'),
      );
    });

    test('an overdue task is in every range', () async {
      final TrajectoryBaseline b = (await _compare(
        <Task>[_task('late', 45, dueDate: day(-3))],
        now: now,
        horizonDays: 7,
      )).baseline;
      expect(b.tasksInHorizon, 1);
      expect(b.requiredMinutesInHorizon, 45);
    });

    test(
      'a scheduled time inside the range counts even if due later',
      () async {
        final TrajectoryBaseline b = (await _compare(
          <Task>[
            _task(
              'soon',
              50,
              dueDate: day(60),
              scheduledFor: DateTime(2026, 12, 3, 10),
            ),
          ],
          now: now,
          horizonDays: 7,
        )).baseline;
        expect(b.tasksInHorizon, 1);
      },
    );

    test(
      'a whole-day deadline on day 7 is inside 7 days for that whole day',
      () async {
        for (final DateTime clock in <DateTime>[
          DateTime(2026, 12, 1, 0, 5),
          now,
          DateTime(2026, 12, 1, 23, 55),
        ]) {
          final TrajectoryBaseline b = (await _compare(
            <Task>[
              _task('day7', 40, dueDate: DateTime(2026, 12, 8)),
              _task('day8', 40, dueDate: DateTime(2026, 12, 9)),
            ],
            now: clock,
            horizonDays: 7,
          )).baseline;
          expect(b.tasksInHorizon, 1, reason: 'at $clock');
          expect(b.requiredMinutesInHorizon, 40, reason: 'at $clock');
        }
      },
    );

    test(
      'a deadline with a time ends the range at the same clock time',
      () async {
        final TrajectoryBaseline b = (await _compare(
          <Task>[
            _task('before', 20, dueDate: DateTime(2026, 12, 8, 8, 30)),
            _task('after', 20, dueDate: DateTime(2026, 12, 8, 9, 30)),
          ],
          now: now,
          horizonDays: 7,
        )).baseline;
        expect(b.tasksInHorizon, 1);
      },
    );

    test('a range across a daylight-saving change still has 7 days', () async {
      // Calendar-day arithmetic: the range ends 7 local days later at the
      // same wall-clock time, whatever the clock change does to the hours.
      final TrajectoryBaseline spring = (await _compare(
        <Task>[
          _task('in', 20, dueDate: DateTime(2026, 3, 12, 8, 30)),
          _task('out', 20, dueDate: DateTime(2026, 3, 12, 9, 30)),
        ],
        now: DateTime(2026, 3, 5, 9),
        horizonDays: 7,
      )).baseline;
      expect(spring.tasksInHorizon, 1);
      final TrajectoryBaseline fall = (await _compare(
        <Task>[
          _task('in', 20, dueDate: DateTime(2026, 11, 5, 8, 30)),
          _task('out', 20, dueDate: DateTime(2026, 11, 5, 9, 30)),
        ],
        now: DateTime(2026, 10, 29, 9),
        horizonDays: 7,
      )).baseline;
      expect(fall.tasksInHorizon, 1);
    });
  });

  group('workload is measured against free time', () {
    test('the brief fixture: next 7 days need 5% of free time', () async {
      final TrajectoryBaseline b = (await _compare(
        briefTasks(),
        now: now,
        horizonDays: 90,
      )).baseline;
      // 90 minutes / (240 x 7) = 5.4%: the fixed next-7-days window, whatever
      // range is chosen.
      expect(b.pressure, 5);
    });

    test('seven undated 15-minute tasks are light (6), not high', () async {
      final TrajectoryBaseline b = (await _compare(
        <Task>[for (int i = 0; i < 7; i++) _task('small-$i', 15)],
        now: now,
        horizonDays: 7,
      )).baseline;
      expect(b.pressure, 6);
    });

    test('workload does not go down when required minutes grow', () async {
      int previous = -1;
      for (int count = 0; count <= 12; count++) {
        final TrajectoryBaseline b = (await _compare(
          <Task>[for (int i = 0; i < count; i++) _task('w$i', 45)],
          now: now,
          horizonDays: 7,
        )).baseline;
        expect(b.pressure, greaterThanOrEqualTo(previous), reason: '$count');
        previous = b.pressure;
      }
      expect(previous, 32);
    });

    test('splitting a 120-minute task into eight 15-minute tasks', () async {
      final TrajectoryBaseline whole = (await _compare(
        <Task>[_task('whole', 120, dueDate: day(2))],
        now: now,
        horizonDays: 7,
      )).baseline;
      final TrajectoryBaseline split = (await _compare(
        <Task>[for (int i = 0; i < 8; i++) _task('p$i', 15, dueDate: day(2))],
        now: now,
        horizonDays: 7,
      )).baseline;
      expect(whole.pressure, 7);
      expect(split.pressure, whole.pressure);
    });

    test('no free time with work present is 100', () async {
      final TrajectoryBaseline b = (await _compare(
        <Task>[_task('x', 15)],
        now: now,
        horizonDays: 7,
        freeMinutes: 0,
      )).baseline;
      expect(b.dailyFreeMinutes, 0);
      expect(b.pressure, 100);
    });

    test('a task scheduled today is not also taken out of free time', () async {
      final TrajectoryBaseline loose = (await _compare(
        <Task>[_task('t', 240, dueDate: day(3))],
        now: now,
        horizonDays: 7,
      )).baseline;
      final TrajectoryBaseline scheduled = (await _compare(
        <Task>[
          _task(
            't',
            240,
            dueDate: day(3),
            scheduledFor: DateTime(2026, 12, 1, 10),
          ),
        ],
        now: now,
        horizonDays: 7,
      )).baseline;
      expect(scheduled.dailyFreeMinutes, loose.dailyFreeMinutes);
      expect(scheduled.dailyFreeMinutes, 240);
      expect(scheduled.pressure, loose.pressure);
      expect(scheduled.pressureInHorizon, loose.pressureInHorizon);
    });

    test('the same plan gives the same load at 09:00 and at 18:00', () async {
      List<Task> plan() => <Task>[
        _task(
          't',
          240,
          dueDate: day(3),
          scheduledFor: DateTime(2026, 12, 1, 10),
        ),
        _task('u', 60),
      ];
      for (final int? free in <int?>[null, 240]) {
        final List<WorkWindowEntity>? windows = free == null
            ? null
            : <WorkWindowEntity>[
                WorkWindowEntity(
                  id: 'day',
                  start: DateTime(2026, 12, 1, 9),
                  end: DateTime(2026, 12, 1, 13),
                ),
              ];
        final TrajectoryBaseline morning = (await _compare(
          plan(),
          now: DateTime(2026, 12, 1, 9),
          horizonDays: 7,
          freeMinutes: free,
          windows: windows,
        )).baseline;
        final TrajectoryBaseline evening = (await _compare(
          plan(),
          now: DateTime(2026, 12, 1, 18),
          horizonDays: 7,
          freeMinutes: free,
          windows: windows,
        )).baseline;
        expect(morning.dailyFreeMinutes, free ?? 480, reason: '$free');
        expect(evening.dailyFreeMinutes, morning.dailyFreeMinutes);
        expect(evening.pressure, morning.pressure, reason: '$free');
      }
    });

    test('configured availability over several days gives one day', () async {
      final TrajectoryBaseline b = (await _compare(
        <Task>[_task('t', 60, dueDate: day(2))],
        now: now,
        horizonDays: 7,
        windows: <WorkWindowEntity>[
          WorkWindowEntity(
            id: 'mon-am',
            start: DateTime(2026, 12, 1, 9),
            end: DateTime(2026, 12, 1, 11),
          ),
          WorkWindowEntity(
            id: 'mon-pm',
            start: DateTime(2026, 12, 1, 14),
            end: DateTime(2026, 12, 1, 16),
          ),
          WorkWindowEntity(
            id: 'tue',
            start: DateTime(2026, 12, 2, 9),
            end: DateTime(2026, 12, 2, 13),
          ),
        ],
      )).baseline;
      expect(b.dailyFreeOrigin, PredictiveEvidenceOrigin.observed);
      // 480 configured minutes over two days: 240 a day.
      expect(b.dailyFreeMinutes, 240);
    });

    test('one long task scheduled today does not read as full', () async {
      final TrajectoryBaseline b = (await _compare(
        <Task>[_task('long', 480, dueDate: day(1), scheduledFor: now)],
        now: now,
        horizonDays: 7,
        freeMinutes: null,
      )).baseline;
      // 480 / (480 x 7) = 14%, not 100.
      expect(b.dailyFreeMinutes, 480);
      expect(b.pressure, 14);
    });

    test('no work is 0', () async {
      final TrajectoryBaseline b = (await _compare(
        <Task>[],
        now: now,
        horizonDays: 7,
      )).baseline;
      expect(b.pressure, 0);
    });

    test('heavy work is clamped to 100', () async {
      final TrajectoryBaseline b = (await _compare(
        <Task>[for (int i = 0; i < 20; i++) _task('h$i', 120)],
        now: now,
        horizonDays: 7,
      )).baseline;
      expect(b.pressure, 100);
    });
  });

  group('projections use the chosen range', () {
    TrajectoryScenarioOutcome keepGoing(TrajectoryComparison c) =>
        c.outcomes.firstWhere(
          (TrajectoryScenarioOutcome o) =>
              o.intervention.type == TrajectoryInterventionType.maintainCourse,
        );

    test('keep going differs between 7 and 90 days (acceptance)', () async {
      final TrajectoryComparison seven = await _compare(
        briefTasks(),
        now: now,
        horizonDays: 7,
      );
      final TrajectoryComparison ninety = await _compare(
        briefTasks(),
        now: now,
        horizonDays: 90,
      );
      expect(
        keepGoing(seven).projectedPressure,
        isNot(keepGoing(ninety).projectedPressure),
      );
      // 90 / (240 x 7) = 5.4% and 210 / (240 x 90) = 1.0%.
      expect(keepGoing(seven).projectedPressure, 5);
      expect(keepGoing(ninety).projectedPressure, 1);
    });

    test(
      'keep going holds steady against the range workload at 7, 30 and 90 days',
      () async {
        final Map<int, int> projected = <int, int>{};
        for (final int days in const <int>[7, 30, 90]) {
          final TrajectoryComparison c = await _compare(
            briefTasks(),
            now: now,
            horizonDays: days,
          );
          final TrajectoryScenarioOutcome k = keepGoing(c);
          // Home keeps the next-7-days value at every range.
          expect(c.baseline.pressure, 5, reason: '$days');
          expect(c.baseline.pressureInHorizon, k.projectedPressure);
          final TrajectoryRiskContribution load = k.risk.contributions
              .firstWhere(
                (TrajectoryRiskContribution r) => r.code == 'pressure',
              );
          expect(load.currentScore, c.baseline.pressureInHorizon);
          expect(load.projectedScore, load.currentScore, reason: '$days');
          projected[days] = k.projectedPressure;
        }
        expect(projected, <int, int>{7: 5, 30: 1, 90: 1});
      },
    );

    test('completing a task in the range removes its minutes', () async {
      final TrajectoryComparison c = await _compare(
        <Task>[
          _task('big', 600, dueDate: day(2), priority: 5),
          _task('small', 240, dueDate: day(3), priority: 1),
        ],
        now: now,
        horizonDays: 7,
      );
      final int base = keepGoing(c).projectedPressure;
      // 840 / 1680 = 50%.
      expect(base, 50);
      final TrajectoryScenarioOutcome reduce = c.outcomes.firstWhere(
        (TrajectoryScenarioOutcome o) =>
            o.intervention.type == TrajectoryInterventionType.reduceScope,
      );
      final String reduced = reduce.intervention.subjectId!;
      final int minutes = reduced == 'big' ? 600 : 240;
      expect(reduce.projectedPressure, ((840 - minutes) * 100 / 1680).round());
      for (final TrajectoryScenarioOutcome o in c.outcomes.where(
        (TrajectoryScenarioOutcome o) =>
            o.intervention.type == TrajectoryInterventionType.delayTask,
      )) {
        // A delay keeps the work.
        expect(o.projectedPressure, base);
      }
    });

    test('a task outside the range brings no relief there', () async {
      final TrajectoryComparison c = await _compare(
        <Task>[
          _task('near', 240, dueDate: day(2), priority: 5),
          _task('far', 600, dueDate: day(40), priority: 1),
        ],
        now: now,
        horizonDays: 7,
      );
      final TrajectoryScenarioOutcome reduceFar = c.outcomes.firstWhere(
        (TrajectoryScenarioOutcome o) =>
            o.intervention.type == TrajectoryInterventionType.reduceScope &&
            o.intervention.subjectId == 'far',
      );
      expect(reduceFar.projectedPressure, keepGoing(c).projectedPressure);
    });

    test(
      'goal dates are the same at every range and say what they assume',
      () async {
        final GoalEntity goal = GoalEntity(
          id: 'goal',
          title: 'Launch',
          createdAt: DateTime(2026, 11, 1),
          targetDate: day(20),
        );
        for (final int horizon in const <int>[7, 30, 90]) {
          final TrajectoryComparison c = await _compare(
            <Task>[
              _task('goal-work', 480, goalId: 'goal'),
              _task('other', 1440, dueDate: day(6)),
            ],
            now: now,
            horizonDays: horizon,
            goals: <GoalEntity>[goal],
          );
          final TrajectoryScenarioOutcome k = keepGoing(c);
          final GoalDelayProjection g = k.goals.single;
          // 480 goal minutes at 240 free minutes a day: 2 local days later.
          expect(
            g.projectedCompletion.toLocal(),
            DateTime(2026, 12, 3, 9),
            reason: '$horizon',
          );
          expect(g.delayDays, 0);
          expect(k.assumptions, contains(trajectoryGoalDateAssumption));
        }
      },
    );

    test('goal dates use calendar days across a clock change (meaningful only '
        'when the machine time zone has daylight saving)', () async {
      final GoalEntity goal = GoalEntity(
        id: 'goal',
        title: 'Launch',
        createdAt: DateTime(2026, 2, 1),
      );
      final TrajectoryComparison c = await _compare(
        <Task>[_task('goal-work', 480, goalId: 'goal')],
        now: DateTime(2026, 3, 7, 9),
        horizonDays: 7,
        goals: <GoalEntity>[goal],
      );
      expect(
        keepGoing(c).goals.single.projectedCompletion.toLocal(),
        DateTime(2026, 3, 9, 9),
      );
    });
  });

  group('availability not observed', () {
    test('uses the assumed workday, says so, and still withholds', () async {
      final GoalEntity goal = GoalEntity(
        id: 'goal',
        title: 'Launch',
        createdAt: DateTime(2026, 11, 1),
        targetDate: day(20),
      );
      final TrajectoryComparison c = await _compare(
        <Task>[_task('goal-work', 60, goalId: 'goal', dueDate: day(2))],
        now: now,
        horizonDays: 7,
        freeMinutes: null,
        goals: <GoalEntity>[goal],
      );
      final TrajectoryBaseline b = c.baseline;
      expect(b.hasObservedAvailability, isFalse);
      // The planner's assumed 09:00-17:00 workday.
      expect(b.dailyFreeMinutes, 480);
      expect(b.dailyFreeOrigin, PredictiveEvidenceOrigin.estimated);
      expect(b.assumptions, contains(contains('based on an assumed workday')));
      expect(b.pressure, 2);
      for (final TrajectoryScenarioOutcome o in c.outcomes) {
        expect(o.goals, isEmpty);
        expect(
          o.assumptions,
          contains(
            'No observed availability is configured. Capacity-based risk and goal completion dates are withheld.',
          ),
        );
        expect(
          o.assumptions,
          contains(contains('based on an assumed workday')),
        );
        final TrajectoryRiskContribution capacity = o.risk.contributions
            .firstWhere((TrajectoryRiskContribution r) => r.code == 'capacity');
        expect(capacity.isScored, isFalse);
        expect(capacity.currentScore, 0);
        expect(capacity.projectedScore, 0);
      }
      expect(trajectoryCanRecommend(c), isFalse);
    });

    test('observed availability makes no assumed-workday claim', () async {
      final TrajectoryBaseline b = (await _compare(
        <Task>[_task('x', 60, dueDate: day(2))],
        now: now,
        horizonDays: 7,
      )).baseline;
      expect(b.assumptions, isNot(contains(contains('assumed workday'))));
    });
  });

  group('revision and model version', () {
    test('changing the range changes the revision', () async {
      final TrajectoryComparison seven = await _compare(
        briefTasks(),
        now: now,
        horizonDays: 7,
      );
      final TrajectoryComparison thirty = await _compare(
        briefTasks(),
        now: now,
        horizonDays: 30,
      );
      expect(seven.baseline.sourceRevisions['horizon'], '7');
      expect(thirty.baseline.sourceRevisions['horizon'], '30');
      expect(seven.baseline.revision, isNot(thirty.baseline.revision));
    });

    test('outcomes and new receipts carry model v4', () async {
      final TrajectoryComparison c = await _compare(
        briefTasks(),
        now: now,
        horizonDays: 7,
      );
      expect(
        c.outcomes.map((TrajectoryScenarioOutcome o) => o.modelVersion),
        everyElement('trajectory-consequence-v4'),
      );
      final TrajectoryForecastReceipt receipt =
          TrajectoryForecastReceipt.fromScenario(
            baseline: c.baseline,
            outcome: c.outcomes.first,
            selectedAt: now.toUtc(),
          );
      expect(receipt.modelVersion, 'trajectory-consequence-v4');
    });

    test('a stored v3 receipt loads and round-trips byte for byte', () {
      const String stored =
          '{"schemaVersion":2,"id":"trajectory-v3-1a2b:maintain-course:1786892400000000",'
          '"accountScope":"v2.test-account","baselineRevision":"trajectory-v3-1a2b",'
          '"scenarioId":"trajectory-v3-1a2b:maintain-course",'
          '"interventionType":"maintainCourse",'
          '"generatedAt":"2026-08-16T15:00:00.000Z",'
          '"selectedAt":"2026-08-16T15:00:00.000Z","horizonSeconds":604800,'
          '"projectedMomentum":61,"projectedPressure":58,"uncertainty":15,'
          '"projectedRiskScore":44,"confidenceBand":"moderate",'
          '"modelVersion":"trajectory-consequence-v3",'
          '"assumptions":["Current completion and deferral rates remain directionally similar."],'
          '"personContextRevision":null,"personContextSignalIds":[],'
          '"assumptionsCorrectedAt":null,'
          '"observed":{"observedAt":"2026-08-23T15:00:00.000Z","momentum":64,'
          '"pressure":52,"completedInWindow":6,"deferredInWindow":2}}';
      final TrajectoryForecastReceipt receipt =
          TrajectoryForecastReceipt.fromJson(
            jsonDecode(stored) as Map<String, dynamic>,
          );
      expect(receipt.modelVersion, 'trajectory-consequence-v3');
      expect(jsonEncode(receipt.toJson()), stored);
    });
  });

  group('minimum evidence is unchanged', () {
    test('2 observed outcomes still show the learning state', () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          trajectoryConsequenceProvider.overrideWithValue(
            AsyncData<TrajectoryComparison>(
              trajectoryTestComparison(
                baseline: trajectoryTestBaseline(observationCount: 2),
              ),
            ),
          ),
          trajectorySummaryProvider.overrideWithValue(trajectoryTestSummary()),
          momentumEngineProvider.overrideWithValue(trajectoryTestMomentum),
          decisionIntelligenceProvider.overrideWithValue(
            const AsyncLoading<DecisionIntelligence>(),
          ),
          networkInterfaceAvailabilityProvider.overrideWithValue(
            NetworkInterfaceAvailability.available,
          ),
        ],
      );
      addTearDown(container.dispose);
      final TrajectoryEngineModel model = container.read(
        trajectoryEngineModelProvider,
      );
      expect(trajectoryMinimumObservedOutcomes, 3);
      expect(model.status, TrajectoryEngineStatus.learning);
      expect(model.comparison, isNull);
    });

    test('2 outcomes from the live provider are below the minimum', () async {
      final TrajectoryComparison c = await _compare(
        briefTasks(),
        now: now,
        horizonDays: 7,
        completed7d: 2,
      );
      expect(c.baseline.observationCount, 2);
      expect(trajectoryHasMinimumEvidence(c), isFalse);
    });

    test('the recommendation gate stays at 5 outcomes', () {
      expect(
        trajectoryCanRecommend(
          trajectoryTestComparison(
            baseline: trajectoryTestBaseline(observationCount: 4),
          ),
        ),
        isFalse,
      );
      expect(
        trajectoryCanRecommend(
          trajectoryTestComparison(
            baseline: trajectoryTestBaseline(observationCount: 5),
          ),
        ),
        isTrue,
      );
    });
  });
}

Task _task(
  String id,
  int minutes, {
  DateTime? dueDate,
  DateTime? scheduledFor,
  String? goalId,
  int priority = 3,
}) => Task(
  id: id,
  title: 'Task $id',
  priority: priority,
  difficulty: 2,
  energyRequired: 2,
  dueDate: dueDate,
  scheduledFor: scheduledFor,
  goalId: goalId,
  estimatedDuration: Duration(minutes: minutes),
  createdAt: DateTime(2026, 11, 1),
);

/// Builds the live comparison for [tasks] at a fixed local clock. With
/// [freeMinutes] a configured (observed) work window of that length starts at
/// [now]; null leaves availability unconfigured so the planner assumes its
/// workday.
Future<TrajectoryComparison> _compare(
  List<Task> tasks, {
  required DateTime now,
  required int horizonDays,
  int completed7d = 7,
  int? freeMinutes = 240,
  List<WorkWindowEntity>? windows,
  List<GoalEntity> goals = const <GoalEntity>[],
}) async {
  final DecisionRecommendation decision = const DecisionEngine().recommend(
    inputs: PlannerInputAdapter.fromLegacyTasks(tasks),
    state: SiStateEntity(
      energy: .7,
      attention: .8,
      fatigue: .2,
      lastUpdated: now,
    ),
    learning: LearningEntity(),
    workWindows:
        windows ??
        (freeMinutes == null
            ? const <WorkWindowEntity>[]
            : <WorkWindowEntity>[
                WorkWindowEntity(
                  id: 'window',
                  start: now,
                  end: now.add(Duration(minutes: freeMinutes)),
                ),
              ]),
    now: now,
  );
  final SIStateAggregation aggregation = SIStateAggregation(
    tasks: tasks,
    goals: goals,
    signals: const SignalsBundle(
      items: <Signal>[],
      summary: 'Stable',
      healthScore: .7,
    ),
    planningEvidence: const SIPlanningEvidence(
      friction: false,
      overwhelm: false,
      streakHealth: 'steady',
      goalDrift: false,
      taskAvoidance: false,
      emotion: 'neutral',
      emotionalStrain: false,
      emotionalStability: true,
      emotionalPatterns: <String>[],
    ),
    logs: const [],
    timeline: const [],
    memories: const [],
    notifications: const [],
    planPreview: const [],
    profile: ProfileState(),
    siState: const SIState(energy: .7, fatigue: .2),
    trajectory: _summary,
    planningDecision: decision,
    noContextPlanningDecision: decision,
  );
  final ProviderContainer container = ProviderContainer(
    overrides: [
      accountStorageScopeProvider.overrideWithValue(
        AccountStorageScope.authenticated('test-account'),
      ),
      siStateAggregationProvider.overrideWith((Ref ref) async => aggregation),
      progressionProvider.overrideWithValue(ProgressionState.initial()),
      executionSignalsProvider.overrideWithValue(
        ExecutionSignals(
          createdToday: 0,
          completedToday: 0,
          skippedToday: 0,
          delayedToday: 0,
          created7d: completed7d,
          completed7d: completed7d,
          skipped7d: 0,
          delayed7d: 0,
        ),
      ),
      personContextForSurfaceProvider(
        trajectoryPersonContextRequest,
      ).overrideWithValue(null),
      trajectoryClockProvider.overrideWithValue(() => now.toUtc()),
    ],
  );
  addTearDown(container.dispose);
  container.read(trajectoryHorizonDaysProvider.notifier).select(horizonDays);
  await container.read(siStateAggregationProvider.future);
  return container.read(trajectoryConsequenceProvider).requireValue;
}

const TrajectorySummaryView _summary = TrajectorySummaryView(
  pendingTasks: 3,
  completedTasks: 7,
  completedToday: 0,
  level: 1,
  streak: 0,
  energy: .7,
  momentum: .5,
  adaptability: .5,
  lastCompletionXp: 0,
  lastCompletionQuality: 0,
  // The shared pressure index is deliberately different: the forecast keeps
  // its own capacity load and never changes this value.
  pressureIndex: 64,
  behaviorDivergence: 0,
  alert: '',
  predictionTitle: null,
  predictionOutcome: null,
  predictionProbability: null,
  predictionExplanation: null,
);
