import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_simulation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/phase10/deterministic_generators.dart';

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
          ).addXp(0);
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
                lastSessionXp: g.between(0, 100),
                lastSessionQuality: g.between(0, 100) / 100,
                pressureIndex: pressure,
                behaviorDivergence: g.between(0, 100),
                alert: 'Generated fixture only.',
                predictionTitle: 'Scenario',
                predictionOutcome: 'Generated projection.',
                predictionProbability: g.between(0, 100) / 100,
                predictionExplanation: 'Deterministic generated fixture.',
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
