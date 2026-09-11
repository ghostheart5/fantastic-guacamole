import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/nexus_vitals_provider.dart';
import 'package:fantastic_guacamole/state/providers/operating_system_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_engine_model_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/trajectory_test_fixture.dart';

void main() {
  test(
    'Home follows Trajectory recent evidence, baseline and refresh failures',
    () async {
      final source =
          NotifierProvider<
            _ComparisonController,
            AsyncValue<TrajectoryComparison>
          >(_ComparisonController.new);
      final container = ProviderContainer(
        overrides: [
          trajectoryConsequenceProvider.overrideWith(
            (ref) => ref.watch(source),
          ),
          trajectorySummaryProvider.overrideWithValue(_summary),
          momentumEngineProvider.overrideWithValue(
            const MomentumEngineState(
              score: 99,
              trend: 'Stable',
              recovery: '',
              forecast: '',
              energyPercent: 50,
              pressurePercent: 0,
              streak: 0,
              completedToday: 0,
            ),
          ),
          decisionIntelligenceProvider.overrideWithValue(
            const AsyncLoading<DecisionIntelligence>(),
          ),
          networkInterfaceAvailabilityProvider.overrideWithValue(
            NetworkInterfaceAvailability.available,
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(nexusMomentumLabelProvider, (_, _) {});
      final controller = container.read(source.notifier);
      // Lifetime completions and the separate composite score cannot bypass the
      // minimum recent-outcome evidence used by the actual Trajectory model.
      expect(container.read(nexusMomentumLabelProvider), 'LEARNING');
      expect(
        container.read(nexusTrajectoryVitalsProvider).momentumPercent,
        isNull,
      );
      expect(
        container.read(nexusTrajectoryVitalsProvider).pressurePercent,
        isNull,
      );
      expect(
        container.read(trajectoryEngineModelProvider).status,
        TrajectoryEngineStatus.learning,
      );
      for (final entry in {
        44: 'BUILDING',
        45: 'STEADY',
        71: 'STEADY',
        72: 'STRONG',
      }.entries) {
        controller.set(
          AsyncData(
            trajectoryTestComparison(
              baseline: trajectoryTestBaseline(
                momentum: entry.key,
                observationCount: 3,
              ),
            ),
          ),
        );
        expect(container.read(nexusMomentumLabelProvider), entry.value);
        expect(
          container.read(nexusTrajectoryVitalsProvider).momentumPercent,
          entry.key,
        );
        expect(
          container.read(nexusTrajectoryVitalsProvider).pressurePercent,
          58,
        );
        expect(container.read(nexusTrajectoryVitalsProvider).activeCount, 2);
        expect(
          container
              .read(trajectoryEngineModelProvider)
              .comparison!
              .baseline
              .momentum,
          entry.key,
        );
      }
      final previous = container.read(source);
      // Deliberately construct stale async data to exercise the refresh boundary.
      controller.set(
        // ignore: invalid_use_of_internal_member
        const AsyncLoading<TrajectoryComparison>().copyWithPrevious(previous),
      );
      expect(container.read(nexusMomentumLabelProvider), 'UPDATING');
      expect(
        container.read(nexusTrajectoryVitalsProvider).momentumPercent,
        isNull,
      );
      expect(
        container.read(nexusTrajectoryVitalsProvider).pressurePercent,
        isNull,
      );
      controller.set(
        AsyncError<TrajectoryComparison>(
          StateError('unavailable'),
          StackTrace.current,
        ),
      );
      expect(container.read(nexusMomentumLabelProvider), 'UNAVAILABLE');
      controller.set(
        AsyncData(
          trajectoryTestComparison(
            baseline: trajectoryTestBaseline(momentum: 10, observationCount: 0),
          ),
        ),
      );
      expect(container.read(nexusMomentumLabelProvider), 'LEARNING');
    },
  );
}

class _ComparisonController extends Notifier<AsyncValue<TrajectoryComparison>> {
  @override
  AsyncValue<TrajectoryComparison> build() => AsyncData(
    trajectoryTestComparison(
      baseline: trajectoryTestBaseline(momentum: 99, observationCount: 2),
    ),
  );
  void set(AsyncValue<TrajectoryComparison> value) => state = value;
}

const _summary = TrajectorySummaryView(
  pendingTasks: 2,
  completedTasks: 100,
  completedToday: 0,
  level: 20,
  streak: 14,
  energy: .5,
  momentum: .99,
  adaptability: .5,
  lastCompletionXp: 10,
  lastCompletionQuality: .6,
  pressureIndex: 10,
  behaviorDivergence: 5,
  alert: '',
  predictionTitle: null,
  predictionOutcome: null,
  predictionProbability: null,
  predictionExplanation: null,
);
