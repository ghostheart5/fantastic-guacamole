import 'dart:convert';

import 'package:fantastic_guacamole/data/repositories/trajectory_forecast_ledger_repository.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_forecast_receipt.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_forecast_ledger_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_habit_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/trajectory_habit_container.dart';
import '../../helpers/trajectory_live_container.dart';

/// The forecast is independent of habits: the same outcomes, ids and
/// receipts with and without them, and a check-in never makes it a different
/// forecast. Fixed local clock 2026-12-01 09:00.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final DateTime now = DateTime(2026, 12, 1, 9);
  DateTime daysAgo(int n) => DateTime(now.year, now.month, now.day - n, 9);

  late TrajectoryMemoryStore store;
  late Map<String, List<HabitEntity>> habitsByUser;

  setUp(() {
    store = TrajectoryMemoryStore();
    habitsByUser = <String, List<HabitEntity>>{
      'account-a': <HabitEntity>[
        trajectoryTestHabit('ha', 'Walk A'),
        trajectoryTestHabit('hr', 'Read'),
      ],
    };
  });

  ProviderContainer build() {
    final ProviderContainer container = trajectoryHabitContainer(
      now: now,
      clock: () => now,
      store: store,
      habitsByUser: habitsByUser,
    );
    addTearDown(container.dispose);
    container.listen(trajectoryConsequenceProvider, (_, _) {});
    // Habits are read for the account while the forecast is open.
    container.listen(trajectoryHabitSourceProvider, (_, _) {});
    return container;
  }

  /// The comparison once the account's habits have been read.
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
        await pumpEventQueue();
        return container.read(trajectoryConsequenceProvider).requireValue;
      }
      await Future<void>.delayed(Duration.zero);
    }
    throw StateError('the comparison never settled');
  }

  for (final int range in <int>[7, 30, 90]) {
    test('range $range: the whole comparison and every receipt are '
        'byte-identical with and without habits', () async {
      await trajectorySeedCheckIns(store, 'account-a', <HabitOccurrenceEntity>[
        for (int i = 1; i <= 20; i++)
          trajectoryTestCheckIn(habitsByUser['account-a']![0], daysAgo(i)),
        for (int i = 0; i <= 5; i++)
          trajectoryTestCheckIn(habitsByUser['account-a']![1], daysAgo(i)),
      ]);
      final ProviderContainer withHabits = build();
      withHabits.read(trajectoryHorizonDaysProvider.notifier).select(range);
      final TrajectoryComparison a = await settled(withHabits);
      expect(
        withHabits.read(trajectoryHabitSourceProvider).requireValue.habits,
        hasLength(2),
      );

      habitsByUser['account-a'] = <HabitEntity>[];
      final ProviderContainer without = build();
      without.read(trajectoryHorizonDaysProvider.notifier).select(range);
      final TrajectoryComparison b = await settled(without);

      expect(jsonEncode(_whole(a)), jsonEncode(_whole(b)));
      expect(
        a.outcomes.map((TrajectoryScenarioOutcome o) => o.modelVersion),
        everyElement('trajectory-consequence-v4'),
      );
      for (int i = 0; i < a.outcomes.length; i++) {
        expect(_receipt(a, i, now), _receipt(b, i, now));
      }
    });
  }

  test('the selected option keeps its id across check-ins', () async {
    final ProviderContainer container = build();
    final TrajectoryComparison before = await settled(container);
    final String selected = before.outcomes.last.id;
    await container.read(habitsProvider.future);

    await container
        .read(habitsProvider.notifier)
        .recordHabitAt('ha', daysAgo(1), completed: true);
    await pumpEventQueue();
    final TrajectoryComparison afterYesterday = await settled(container);
    await container.read(habitsProvider.notifier).completeHabit('ha');
    await pumpEventQueue();
    final TrajectoryComparison afterToday = await settled(container);

    expect(
      container.read(trajectoryHabitSourceProvider).requireValue.occurrences,
      hasLength(2),
    );
    expect(afterYesterday.baseline.revision, before.baseline.revision);
    expect(afterToday.baseline.revision, before.baseline.revision);
    expect(
      afterToday.outcomes.map((TrajectoryScenarioOutcome o) => o.id),
      contains(selected),
    );
  });

  test('excluding assumptions after a check-in marks the existing receipt '
      'and adds none', () async {
    final ProviderContainer container = build();
    final TrajectoryComparison before = await settled(container);
    final TrajectoryScenarioOutcome tracked = before.outcomes.first;
    final TrajectoryForecastLedgerRepository ledger = container.read(
      trajectoryForecastLedgerRepositoryProvider,
    );
    expect(
      await ledger.append(
        TrajectoryForecastReceipt.fromScenario(
          baseline: before.baseline,
          outcome: tracked,
          selectedAt: now.toUtc(),
        ),
      ),
      isTrue,
    );
    await container.read(habitsProvider.future);
    await container.read(habitsProvider.notifier).completeHabit('ha');
    await pumpEventQueue();
    final TrajectoryComparison after = await settled(container);
    final TrajectoryScenarioOutcome same = after.outcomes.firstWhere(
      (TrajectoryScenarioOutcome o) =>
          o.intervention.id == tracked.intervention.id,
    );

    await ledger.recordAssumptionCorrection(
      baseline: after.baseline,
      outcome: same,
      correctedAt: now.add(const Duration(minutes: 5)).toUtc(),
    );

    final List<TrajectoryForecastReceipt> receipts = await ledger.load();
    expect(receipts, hasLength(1));
    expect(receipts.single.scenarioId, tracked.id);
    expect(receipts.single.hasAssumptionCorrection, isTrue);
  });
}

String _receipt(TrajectoryComparison c, int index, DateTime now) => jsonEncode(
  TrajectoryForecastReceipt.fromScenario(
    baseline: c.baseline,
    outcome: c.outcomes[index],
    selectedAt: now.toUtc(),
  ).toJson(),
);

/// Every field of the comparison's outcomes, plus the baseline's revision
/// and source revisions, as plain JSON values.
Map<String, Object?> _whole(TrajectoryComparison c) => <String, Object?>{
  'baselineRevision': c.baseline.revision,
  'sourceRevisions': c.baseline.sourceRevisions,
  'recommended': c.recommendedScenarioId,
  'outcomes': <Object?>[
    for (final TrajectoryScenarioOutcome o in c.outcomes)
      <String, Object?>{
        'id': o.id,
        'baselineRevision': o.baselineRevision,
        'intervention': <String, Object?>{
          'id': o.intervention.id,
          'type': o.intervention.type.name,
          'title': o.intervention.title,
          'horizon': o.intervention.horizon.inSeconds,
          'description': o.intervention.description,
          'subjectId': o.intervention.subjectId,
          'delay': o.intervention.delay.inSeconds,
          'proposedBlocks': o.intervention.proposedBlocks
              .map((TrajectoryBlockNode b) => '${b.id}:${b.taskId}')
              .toList(),
          'displaced': o.intervention.displacedSubjectIds,
          'assumptions': o.intervention.assumptions,
        },
        'generatedAt': o.generatedAt.toIso8601String(),
        'momentum': o.projectedMomentum,
        'pressure': o.projectedPressure,
        'uncertainty': o.uncertainty,
        'calibrationMultiplier': o.calibrationMultiplier,
        'confidence': o.confidence.toJson(),
        'risk': <String, Object?>{
          'current': o.risk.currentScore,
          'projected': o.risk.projectedScore,
          'band': o.risk.band.name,
          'contributions': <Object?>[
            for (final TrajectoryRiskContribution r in o.risk.contributions)
              <String, Object?>{
                'code': r.code,
                'label': r.label,
                'current': r.currentScore,
                'projected': r.projectedScore,
                'explanation': r.explanation,
                'scored': r.isScored,
              },
          ],
        },
        'timeline': <String, Object?>{
          'affectedBlockIds': o.timeline.affectedBlockIds,
          'displacedSubjectIds': o.timeline.displacedSubjectIds,
          'deadlineCrossings': o.timeline.deadlineCrossings,
          'minutesAdded': o.timeline.minutesAdded,
          'summary': o.timeline.summary,
        },
        'goals': <Object?>[
          for (final GoalDelayProjection g in o.goals)
            <String, Object?>{
              'goalId': g.goalId,
              'goalTitle': g.goalTitle,
              'targetDate': g.targetDate?.toIso8601String(),
              'projected': g.projectedCompletion.toIso8601String(),
              'lower': g.lowerCompletion.toIso8601String(),
              'upper': g.upperCompletion.toIso8601String(),
              'delayDays': g.delayDays,
              'remainingMinutes': g.remainingMinutes,
              'confidence': g.confidence.toJson(),
              'explanation': g.explanation,
            },
        ],
        'progression': <String, Object?>{
          'potentialXp': o.progression.potentialXp,
          'streakProtected': o.progression.streakProtected,
          'summary': o.progression.summary,
        },
        'evidence': o.evidence,
        'assumptions': o.assumptions,
        'explanation': o.explanation,
        'utility': o.utilityScore,
        'modelVersion': o.modelVersion,
      },
  ],
};
