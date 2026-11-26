import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/engine/trajectory/future_consequence_engine.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_simulation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/phase10/deterministic_generators.dart';
import '../helpers/trajectory_test_fixture.dart';

void main() {
  test(
    'fixed XP inputs preserve progression boundaries and monotonic levels',
    () {
      for (final int seed in phase10Seeds) {
        final DeterministicGenerator g = DeterministicGenerator(seed);
        int previousXp = 0;
        int previousLevel = 1;
        for (int index = 0; index < 80; index++) {
          final int xp = previousXp + g.between(0, 500);
          final ProgressionEntity progression = ProgressionEntity(
            xp: xp,
          ).awardXp(0);
          expect(progression.level, greaterThanOrEqualTo(previousLevel));
          expect(
            ProgressionPolicy.xpForLevel(progression.level),
            lessThanOrEqualTo(xp),
          );
          expect(progression.xpToNextLevel, greaterThan(0));
          previousXp = xp;
          previousLevel = progression.level;
        }
      }
    },
  );

  test(
    'trajectory simulations stay finite and bounded for fixed generated signals',
    () {
      for (final int seed in phase10Seeds) {
        final DeterministicGenerator g = DeterministicGenerator(seed);
        final int momentum = g.between(0, 100);
        final int pressure = g.between(0, 100);
        final int energy = g.between(0, 100);
        final ProviderContainer container = ProviderContainer(
          overrides: [
            momentumEngineProvider.overrideWithValue(
              MomentumEngineState(
                score: momentum,
                trend: 'Generated',
                recovery: 'Generated',
                forecast: 'Generated fixture only.',
                energyPercent: energy,
                pressurePercent: pressure,
                streak: g.between(0, 100),
                completedToday: g.between(0, 20),
              ),
            ),
            trajectorySummaryProvider.overrideWithValue(
              TrajectorySummaryView(
                pendingTasks: g.between(0, 50),
                completedTasks: g.between(0, 50),
                completedToday: g.between(0, 20),
                level: g.between(1, 20),
                streak: g.between(0, 100),
                energy: energy / 100,
                momentum: momentum / 100,
                adaptability: g.between(0, 100) / 100,
                lastCompletionXp: g.between(0, 100),
                lastCompletionQuality: g.between(0, 100) / 100,
                pressureIndex: pressure,
                behaviorDivergence: g.between(0, 100),
                alert: 'Generated fixture only.',
                predictionTitle: 'Scenario',
                predictionOutcome: 'Generated projection.',
                predictionProbability: g.between(0, 100) / 100,
                predictionExplanation: 'Deterministic generated fixture.',
              ),
            ),
            trajectoryConsequenceProvider.overrideWithValue(
              AsyncValue<TrajectoryComparison>.data(
                _comparison(momentum: momentum, pressure: pressure),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        final List<TrajectorySimulationResult> results = container.read(
          trajectorySimulationProvider,
        );
        expect(results, isNotEmpty, reason: 'seed=$seed');
        for (final TrajectorySimulationResult result in results) {
          expect(result.projectedMomentum, inInclusiveRange(0, 100));
          expect(result.projectedPressure, inInclusiveRange(0, 100));
        }
      }
    },
  );

  test('v4 range workload holds its properties for generated plans', () {
    TrajectoryTaskNode node(DeterministicGenerator g, int index) {
      final int kind = g.between(0, 3);
      final DateTime? due = kind == 0
          ? null
          : trajectoryFixtureNow.add(Duration(days: g.between(-5, 120)));
      return TrajectoryTaskNode(
        id: 'generated-$index',
        title: 'Generated $index',
        priority: g.between(1, 5),
        estimatedMinutes: g.between(5, 240),
        dueAt: due,
        scheduledAt: kind == 3
            ? trajectoryFixtureNow.add(Duration(days: g.between(0, 60)))
            : null,
      );
    }

    int keepGoing(
      List<TrajectoryTaskNode> tasks,
      int free,
      int completed,
      int days,
    ) => const FutureConsequenceEngine()
        .project(
          baseline: trajectoryTestBaseline(
            tasks: tasks,
            dailyFreeMinutes: free,
            completedInWindow: completed,
          ),
          generatedAt: trajectoryFixtureNow,
          intervention: TrajectoryIntervention(
            id: 'maintain',
            type: TrajectoryInterventionType.maintainCourse,
            title: 'Maintain current course',
            horizon: Duration(days: days),
            description: 'Generated fixture only.',
          ),
        )
        .projectedPressure;

    for (final int seed in phase10Seeds) {
      final DeterministicGenerator g = DeterministicGenerator(seed);
      final int free = g.between(0, 600);
      final int completed = g.between(0, 30);
      final int count = g.between(0, 25);
      final List<TrajectoryTaskNode> tasks = <TrajectoryTaskNode>[
        for (int i = 0; i < count; i++) node(g, i),
      ];
      final TrajectoryTaskNode extra = node(g, 99);
      int previousCount = -1;
      for (final int days in const <int>[7, 30, 90]) {
        final TrajectoryHorizonWorkload w =
            FutureConsequenceEngine.horizonWorkload(
              tasks: tasks,
              now: trajectoryFixtureNow,
              horizonDays: days,
              completedLast7Days: completed,
            );
        // Longer ranges hold at least the work of shorter ones.
        expect(w.taskCount, greaterThanOrEqualTo(previousCount));
        previousCount = w.taskCount;
        final TrajectoryExpectedCompletions e = w.expectedCompletions;
        expect(e.low, inInclusiveRange(0, e.mid), reason: 'seed=$seed');
        expect(e.high, inInclusiveRange(e.mid, w.taskCount));
        final int load = keepGoing(tasks, free, completed, days);
        expect(load, inInclusiveRange(0, 100), reason: 'seed=$seed');
        // More work never lowers the load.
        expect(
          keepGoing(
            <TrajectoryTaskNode>[...tasks, extra],
            free,
            completed,
            days,
          ),
          greaterThanOrEqualTo(load),
          reason: 'seed=$seed days=$days',
        );
        if (free == 0) {
          expect(load, w.requiredMinutes > 0 ? 100 : 0);
        }
      }
    }
  });
}

TrajectoryComparison _comparison({
  required int momentum,
  required int pressure,
}) {
  final TrajectoryBaseline source = trajectoryTestBaseline(
    momentum: momentum,
    pressure: pressure,
  );
  return const FutureConsequenceEngine().compare(
    baseline: source,
    generatedAt: trajectoryFixtureNow,
    interventions: <TrajectoryIntervention>[
      TrajectoryIntervention(
        id: 'maintain',
        type: TrajectoryInterventionType.maintainCourse,
        title: 'Maintain current course',
        horizon: const Duration(days: 7),
        description: 'Keep the frozen generated baseline unchanged.',
      ),
      TrajectoryIntervention(
        id: 'delay',
        type: TrajectoryInterventionType.delayTask,
        title: 'Delay selected work',
        horizon: const Duration(days: 30),
        description: 'Model a bounded delay.',
        subjectId: 'task-launch',
        delay: const Duration(days: 2),
      ),
    ],
  );
}
