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
