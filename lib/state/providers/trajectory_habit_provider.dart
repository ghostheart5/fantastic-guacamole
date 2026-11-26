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
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The habits and check-ins of one account, as read for the forecast.
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

/// Reads one account's habits and check-ins from the account-scoped stores
/// under an account lease (namespace and auth generation checked after every
/// await). Keyed by `namespace|auth generation`, so a newly signed-in account
/// starts from a clean loading state and never sees the previous account's
/// value, and an entry nobody reads is disposed with its data.
///
/// Live while it is read: a changed habit list (habitsProvider, a trigger
/// only, never awaited) or a recorded check-in (habitOccurrencesProvider)
/// reads it again.
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
      }
    });

/// What the forecast reads: the current account's habit source, or an empty
/// one when storage is not writable.
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
          '${scope.v2Namespace}|$generation',
        ),
      );
    });

/// The habit lines for a baseline and the source revision they add.
class TrajectoryHabitEvidenceView {
  const TrajectoryHabitEvidenceView({required this.nodes, this.revision});

  static const TrajectoryHabitEvidenceView none = TrajectoryHabitEvidenceView(
    nodes: <TrajectoryHabitNode>[],
  );

  final List<TrajectoryHabitNode> nodes;

  /// Null when there are no lines (the revisions then stay as before).
  final String? revision;
}

/// Habit lines for [namespace] over [horizonDays] from [source]. No lines
/// while the source is loading for the first time, when it failed, or when
/// it belongs to another namespace: the forecast is never blocked on habits
/// and never shows another account's.
TrajectoryHabitEvidenceView trajectoryHabitEvidence({
  required AsyncValue<TrajectoryHabitSource> source,
  required String? namespace,
  required DateTime now,
  required int horizonDays,
}) {
  final TrajectoryHabitSource? value = source.hasError ? null : source.value;
  if (value == null || namespace == null || value.namespace != namespace) {
    return TrajectoryHabitEvidenceView.none;
  }
  final List<TrajectoryHabitNode> nodes = TrajectoryHabitProjection.nodes(
    habits: value.habits,
    occurrences: value.occurrences,
    now: now,
    horizonDays: horizonDays,
  );
  return TrajectoryHabitEvidenceView(
    nodes: nodes,
    revision: TrajectoryHabitProjection.revision(nodes),
  );
}
