import 'dart:async';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final planningPeriodClockProvider = Provider<DateTime>((ref) {
  final timer = Timer(const Duration(minutes: 1), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return DateTime.now();
});

final rhythmPlanningProvider = FutureProvider<List<RhythmPlanningEntry>>((
  ref,
) async {
  final now = ref.watch(planningPeriodClockProvider);
  if (!ref.watch(accountStorageScopeProvider).isWritable) return const [];
  // Read canonical data without initializing the UI's reminder coordinator.
  final habits = await ref.watch(getHabitsUseCaseProvider).call();
  if (!ref.mounted) return const [];
  final outcomes = await ref.watch(habitOccurrencesProvider.future);
  return RhythmPlanningContext.build(habits, outcomes, now);
});
