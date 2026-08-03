import 'package:fantastic_guacamole/data/repositories/habit_repository.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Momentum Engine', () {
    test('streak calculations increase score and cap boost effect', () {
      final ProviderContainer lowStreakContainer = _buildContainer(
        profile: ProfileState(streak: 1),
      );
      final ProviderContainer highStreakContainer = _buildContainer(
        profile: ProfileState(streak: 20),
      );
      addTearDown(lowStreakContainer.dispose);
      addTearDown(highStreakContainer.dispose);

      final MomentumEngineState low = lowStreakContainer.read(
        momentumEngineProvider,
      );
      final MomentumEngineState high = highStreakContainer.read(
        momentumEngineProvider,
      );

      expect(low.streak, 1);
      expect(high.streak, 20);
      expect(high.score, greaterThan(low.score));
      expect(high.score - low.score, lessThanOrEqualTo(20));
    });

    test('score changes react to momentum and pressure shifts', () {
      final ProviderContainer favorableContainer = _buildContainer(
        trajectory: _trajectory(momentum: 0.92),
        siState: const SIState(energy: 0.9, fatigue: 0.15, completedToday: 2),
        execution: const ExecutionSignals(
          createdToday: 2,
          completedToday: 3,
          skippedToday: 0,
          delayedToday: 0,
          created7d: 14,
          completed7d: 11,
          skipped7d: 1,
          delayed7d: 1,
        ),
      );
      final ProviderContainer pressuredContainer = _buildContainer(
        trajectory: _trajectory(momentum: 0.28),
        siState: const SIState(energy: 0.25, fatigue: 0.9, completedToday: 0),
        execution: const ExecutionSignals(
          createdToday: 2,
          completedToday: 0,
          skippedToday: 3,
          delayedToday: 2,
          created7d: 14,
          completed7d: 1,
          skipped7d: 5,
          delayed7d: 4,
        ),
      );
      addTearDown(favorableContainer.dispose);
      addTearDown(pressuredContainer.dispose);

      final MomentumEngineState favorable = favorableContainer.read(
        momentumEngineProvider,
      );
      final MomentumEngineState pressured = pressuredContainer.read(
        momentumEngineProvider,
      );

      expect(favorable.score, greaterThan(pressured.score));
      expect(favorable.trend, anyOf('Rising', 'Stable'));
      expect(pressured.trend, anyOf('Stable', 'Declining'));
      expect(pressured.pressurePercent, greaterThan(favorable.pressurePercent));
    });

    test('daily updates propagate completedToday and improve score', () {
      final ProviderContainer lowDailyContainer = _buildContainer(
        siState: const SIState(energy: 0.7, fatigue: 0.3, completedToday: 0),
        execution: const ExecutionSignals(
          createdToday: 0,
          completedToday: 0,
          skippedToday: 0,
          delayedToday: 0,
          created7d: 0,
          completed7d: 0,
          skipped7d: 0,
          delayed7d: 0,
        ),
      );
      final ProviderContainer highDailyContainer = _buildContainer(
        siState: const SIState(energy: 0.7, fatigue: 0.3, completedToday: 3),
        execution: const ExecutionSignals(
          createdToday: 3,
          completedToday: 3,
          skippedToday: 0,
          delayedToday: 0,
          created7d: 9,
          completed7d: 8,
          skipped7d: 0,
          delayed7d: 1,
        ),
      );
      addTearDown(lowDailyContainer.dispose);
      addTearDown(highDailyContainer.dispose);

      final MomentumEngineState lowDaily = lowDailyContainer.read(
        momentumEngineProvider,
      );
      final MomentumEngineState highDaily = highDailyContainer.read(
        momentumEngineProvider,
      );

      expect(lowDaily.completedToday, 0);
      expect(highDaily.completedToday, 3);
      expect(highDaily.score, greaterThan(lowDaily.score));
    });

    test('reset behavior collapses momentum to low baseline', () {
      final ProviderContainer activeContainer = _buildContainer(
        profile: ProfileState(streak: 8),
        siState: const SIState(energy: 0.82, fatigue: 0.22, completedToday: 4),
        execution: const ExecutionSignals(
          createdToday: 4,
          completedToday: 4,
          skippedToday: 0,
          delayedToday: 0,
          created7d: 20,
          completed7d: 16,
          skipped7d: 1,
          delayed7d: 1,
        ),
      );
      final ProviderContainer resetContainer = _buildContainer(
        profile: ProfileState(streak: 0),
        siState: const SIState(energy: 0.45, fatigue: 0.85, completedToday: 0),
        execution: const ExecutionSignals(
          createdToday: 0,
          completedToday: 0,
          skippedToday: 0,
          delayedToday: 0,
          created7d: 0,
          completed7d: 0,
          skipped7d: 0,
          delayed7d: 0,
        ),
      );
      addTearDown(activeContainer.dispose);
      addTearDown(resetContainer.dispose);

      final MomentumEngineState active = activeContainer.read(
        momentumEngineProvider,
      );
      final MomentumEngineState reset = resetContainer.read(
        momentumEngineProvider,
      );

      expect(reset.streak, 0);
      expect(reset.completedToday, 0);
      expect(reset.score, lessThan(active.score));
      expect(reset.recovery, anyOf('Recovery Needed', 'Watch Load'));
    });
  });
}

ProviderContainer _buildContainer({
  ProfileState? profile,
  SIState siState = const SIState(energy: 0.7, fatigue: 0.3, completedToday: 1),
  TrajectorySummaryView? trajectory,
  ExecutionSignals execution = const ExecutionSignals(
    createdToday: 1,
    completedToday: 1,
    skippedToday: 0,
    delayedToday: 0,
    created7d: 7,
    completed7d: 5,
    skipped7d: 1,
    delayed7d: 1,
  ),
  List<HabitRecord> habits = const <HabitRecord>[],
}) {
  final ProfileState resolvedProfile = profile ?? ProfileState();
  return ProviderContainer(
    overrides: [
      profileProvider.overrideWith(() => _StaticProfileController(resolvedProfile)),
      siStateProvider.overrideWith(() => _StaticSiStateController(siState)),
      trajectorySummaryProvider.overrideWithValue(
        trajectory ?? _trajectory(momentum: 0.6),
      ),
      executionSignalsProvider.overrideWithValue(execution),
      habitsProvider.overrideWith(() => _StaticHabitsNotifier(habits)),
    ],
  );
}

TrajectorySummaryView _trajectory({required double momentum}) {
  return TrajectorySummaryView(
    pendingTasks: 3,
    completedTasks: 2,
    completedToday: 1,
    level: 2,
    streak: 1,
    energy: 0.7,
    momentum: momentum,
    adaptability: 0.5,
    lastSessionXp: 10,
    lastSessionQuality: 0.7,
    pressureIndex: 30,
    behaviorDivergence: 10,
    alert: 'ok',
    predictionTitle: null,
    predictionOutcome: null,
    predictionProbability: null,
    predictionExplanation: null,
  );
}

class _StaticProfileController extends ProfileController {
  _StaticProfileController(this._state);

  final ProfileState _state;

  @override
  ProfileState build() => _state;
}

class _StaticSiStateController extends SIStateController {
  _StaticSiStateController(this._state);

  final SIState _state;

  @override
  SIState build() => _state;
}

class _StaticHabitsNotifier extends HabitsNotifier {
  _StaticHabitsNotifier(this._habits);

  final List<HabitRecord> _habits;

  @override
  Future<List<HabitRecord>> build() async => _habits;
}
