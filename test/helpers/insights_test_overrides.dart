import 'package:fantastic_guacamole/engine/patterns/patterns_engine.dart';
import 'package:fantastic_guacamole/state/providers/patterns_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_habit_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// Overrides for widget tests that mount the Insights tab, the Future
/// outcomes screen or Patterns with a signed-in (writable) account.
///
/// The habit lines provider and the Patterns provider each keep a Timer to the
/// next local midnight (their day rollover). A widget test whose container
/// outlives the test body would end with "Pending timers", so tests that do
/// not test these replace them with ready, empty values for the selected
/// range. The providers themselves are not changed.
List<Override> insightsDayRolloverOverrides() => <Override>[
  trajectoryHabitLinesProvider.overrideWith(
    (Ref ref) => TrajectoryHabitLines(
      status: TrajectoryHabitLinesStatus.ready,
      horizonDays: ref.watch(trajectoryHorizonDaysProvider),
    ),
  ),
  patternsProvider.overrideWith(
    (Ref ref) => AsyncData<PatternsResult>(
      PatternsResult.empty(
        now: ref.watch(patternsClockProvider)(),
        rangeDays: ref.watch(patternsRangeDaysProvider),
      ),
    ),
  ),
];
