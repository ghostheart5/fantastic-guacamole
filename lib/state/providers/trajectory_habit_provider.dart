import 'dart:async';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/engine/trajectory/trajectory_habit_projection.dart';
import 'package:fantastic_guacamole/state/providers/account_operation.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/providers/patterns_provider.dart'
    show patternsDayRolloverDelay;
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The habits and check-ins of one account, as read for the habit lines.
class TrajectoryHabitSource {
  TrajectoryHabitSource({
    required this.namespace,
    required List<HabitEntity> habits,
    required List<HabitOccurrenceEntity> occurrences,
  }) : habits = List<HabitEntity>.unmodifiable(habits),
       occurrences = List<HabitOccurrenceEntity>.unmodifiable(occurrences);

  TrajectoryHabitSource.empty(this.namespace)
    : habits = const <HabitEntity>[],
      occurrences = const <HabitOccurrenceEntity>[];

  /// The storage namespace the data was read from.
  final String? namespace;
  final List<HabitEntity> habits;
  final List<HabitOccurrenceEntity> occurrences;
}

/// The key of one account's habit providers: `namespace|auth generation`.
String trajectoryHabitAccountKey(String? namespace, int generation) =>
    '$namespace|$generation';

String _namespaceOf(String accountKey) =>
    accountKey.substring(0, accountKey.lastIndexOf('|'));

/// Reads one account's habits and check-ins from the account-scoped stores
/// under an account lease (namespace and auth generation checked after every
/// await). Keyed by `namespace|auth generation`, so a newly signed-in account
/// starts from a clean loading state and never sees the previous account's
/// value, and an entry nobody reads is disposed with its data.
///
/// Live while it is read: a changed habit list (habitsProvider, a trigger
/// only, never awaited) or a recorded check-in (habitOccurrencesProvider)
/// reads it again. A failed read is logged (its type only, no user data) and
/// surfaces as an error.
final trajectoryHabitSourceForAccountProvider = FutureProvider.autoDispose
    .family<TrajectoryHabitSource, String>((Ref ref, String accountKey) async {
      ref.listen(habitsProvider, (
        AsyncValue<List<HabitEntity>>? previous,
        AsyncValue<List<HabitEntity>> next,
      ) {
        // The first load is skipped: this provider reads the store itself.
        if (next.isLoading || previous == null || !previous.hasValue) return;
        ref.invalidateSelf();
      });
      final AccountOperation owner = AccountOperation.capture(ref);
      try {
        final List<HabitEntity> habits = await owner.wait(
          ref.watch(getHabitsUseCaseProvider).call(),
        );
        final List<HabitOccurrenceEntity> occurrences = await owner.wait(
          ref.watch(habitOccurrencesProvider.future),
        );
        return TrajectoryHabitSource(
          namespace: owner.namespace,
          habits: habits,
          occurrences: occurrences,
        );
      } on StaleAccountOperation {
        // The account changed under this read: nothing of it is kept.
        return TrajectoryHabitSource.empty(owner.namespace);
      } on Object catch (error) {
        Logger.errorCategory(
          'TrajectoryHabitLines',
          'Habits could not be read for the forecast (${error.runtimeType}).',
        );
        rethrow;
      }
    });

/// The current account's habit source, or an empty one when storage is not
/// writable.
final trajectoryHabitSourceProvider =
    Provider.autoDispose<AsyncValue<TrajectoryHabitSource>>((Ref ref) {
      final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
      if (!scope.isWritable) {
        return AsyncData<TrajectoryHabitSource>(
          TrajectoryHabitSource.empty(scope.v2Namespace),
        );
      }
      final int generation = ref.watch(
        authSessionBoundaryProvider.select((b) => b.generation),
      );
      return ref.watch(
        trajectoryHabitSourceForAccountProvider(
          trajectoryHabitAccountKey(scope.v2Namespace, generation),
        ),
      );
    });

/// Whether the habit lines could be worked out.
enum TrajectoryHabitLinesStatus {
  /// The account's habits are still being read for the first time.
  loading,

  /// Read; [TrajectoryHabitLines.nodes] may be empty (no active habits).
  ready,

  /// The read failed, or no account's storage is available.
  unavailable,
}

/// The habit lines shown beside the forecast for the selected range.
class TrajectoryHabitLines {
  TrajectoryHabitLines({
    required this.status,
    required this.horizonDays,
    List<TrajectoryHabitNode> nodes = const <TrajectoryHabitNode>[],
    this.revision = 'none',
  }) : nodes = List<TrajectoryHabitNode>.unmodifiable(nodes);

  final TrajectoryHabitLinesStatus status;
  final int horizonDays;

  /// One line per active habit, ordered by title (empty unless ready).
  final List<TrajectoryHabitNode> nodes;

  /// Changes when a habit or check-in changes the lines; independent of the
  /// forecast's own revision.
  final String revision;
}

/// The lines for [namespace] over [horizonDays] from [source]: loading until
/// the account's first read finishes, unavailable when the read failed or
/// there is no account, and a source of another namespace is never used
/// (treated as still loading).
TrajectoryHabitLines trajectoryHabitLinesFrom({
  required AsyncValue<TrajectoryHabitSource> source,
  required String? namespace,
  required DateTime now,
  required int horizonDays,
}) {
  if (namespace == null || source.hasError) {
    return TrajectoryHabitLines(
      status: TrajectoryHabitLinesStatus.unavailable,
      horizonDays: horizonDays,
    );
  }
  final TrajectoryHabitSource? value = source.value;
  if (value == null || value.namespace != namespace) {
    return TrajectoryHabitLines(
      status: TrajectoryHabitLinesStatus.loading,
      horizonDays: horizonDays,
    );
  }
  final List<TrajectoryHabitNode> nodes = TrajectoryHabitProjection.nodes(
    habits: value.habits,
    occurrences: value.occurrences,
    now: now,
    horizonDays: horizonDays,
  );
  return TrajectoryHabitLines(
    status: TrajectoryHabitLinesStatus.ready,
    horizonDays: horizonDays,
    nodes: nodes,
    revision: TrajectoryHabitProjection.revision(nodes) ?? 'none',
  );
}

/// One account's habit lines, keyed like its source. Synchronous, it never
/// awaits: it follows the source (habit and check-in changes), the selected
/// range and the forecast clock, and is worked out again when the local day
/// changes. Only the key's own account can appear in it.
final trajectoryHabitLinesForAccountProvider = Provider.autoDispose
    .family<TrajectoryHabitLines, String>((Ref ref, String accountKey) {
      final int horizonDays = ref.watch(trajectoryHorizonDaysProvider);
      final DateTime now = ref.watch(trajectoryClockProvider)();
      final Timer rollover = Timer(patternsDayRolloverDelay(now), () {
        ref.invalidateSelf();
      });
      ref.onDispose(rollover.cancel);
      return trajectoryHabitLinesFrom(
        source: ref.watch(trajectoryHabitSourceForAccountProvider(accountKey)),
        namespace: _namespaceOf(accountKey),
        now: now,
        horizonDays: horizonDays,
      );
    });

/// What the screen reads beside the comparison: the current account's habit
/// lines for the selected range, with an explicit status. A separate state per
/// account and sign-in, so a new account starts from loading and never shows
/// the previous account's lines. Unavailable when storage is not writable.
/// The comparison itself never reads habits.
final trajectoryHabitLinesProvider = Provider.autoDispose<TrajectoryHabitLines>(
  (Ref ref) {
    final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
    if (!scope.isWritable || scope.v2Namespace == null) {
      return TrajectoryHabitLines(
        status: TrajectoryHabitLinesStatus.unavailable,
        horizonDays: ref.watch(trajectoryHorizonDaysProvider),
      );
    }
    final int generation = ref.watch(
      authSessionBoundaryProvider.select((b) => b.generation),
    );
    return ref.watch(
      trajectoryHabitLinesForAccountProvider(
        trajectoryHabitAccountKey(scope.v2Namespace, generation),
      ),
    );
  },
);
