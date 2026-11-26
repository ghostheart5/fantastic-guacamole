import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_habit_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// Overrides for widget tests that mount the Insights tab or the Future
/// outcomes screen with a signed-in (writable) account.
///
/// The habit lines provider keeps a Timer to the next local midnight (its day
/// rollover). A widget test whose container outlives the test body would end
/// with "Pending timers", so tests that do not test habit lines replace them
/// with a ready, empty value for the selected range. The providers themselves
/// are not changed. (The Patterns provider has the same kind of timer; add
/// it here when a test needs it.)
List<Override> insightsDayRolloverOverrides() => <Override>[
  trajectoryHabitLinesProvider.overrideWith(
    (Ref ref) => TrajectoryHabitLines(
      status: TrajectoryHabitLinesStatus.ready,
      horizonDays: ref.watch(trajectoryHorizonDaysProvider),
    ),
  ),
];
