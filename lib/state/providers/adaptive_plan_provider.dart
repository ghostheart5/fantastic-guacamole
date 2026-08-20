import 'package:fantastic_guacamole/domain/entities/plan_entity.dart';
import 'package:fantastic_guacamole/domain/entities/plan_proposal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/domain/planning/planner_input.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Injectable clock for deterministic schedule projections and tests.
final adaptivePlanClockProvider = Provider<DateTime Function()>((Ref ref) {
  return DateTime.now;
});

final planProposalProvider =
    AsyncNotifierProvider<PlanProposalNotifier, PlanProposalEntity?>(
      PlanProposalNotifier.new,
    );

class PlanProposalNotifier extends AsyncNotifier<PlanProposalEntity?> {
  @override
  Future<PlanProposalEntity?> build() async => null;

  Future<PlanProposalEntity> preview({
    required List<PlannerInput> inputs,
    required double energy,
    DateTime? startTime,
    String? sourceDecisionId,
    List<String> evidenceSources = const <String>['tasks', 'calendar'],
  }) async {
    state = const AsyncLoading<PlanProposalEntity?>();
    final PlanProposalEntity proposal = await ref
        .read(previewAdaptivePlanUseCaseProvider)
        .call(
          inputs: inputs,
          energy: energy,
          startTime: startTime,
          sourceDecisionId: sourceDecisionId,
          evidenceSources: evidenceSources,
          policy: ref.read(adaptivePlanPolicyProvider),
        );
    state = AsyncData<PlanProposalEntity?>(proposal);
    return proposal;
  }

  Future<PlanEntity?> apply() async {
    final PlanProposalEntity? proposal = state.asData?.value;
    if (proposal == null) return null;
    final DateTime now = DateTime.now();
    final PlanEntity plan = await ref
        .read(applyPlanProposalUseCaseProvider)
        .call(proposal, now: now);
    state = AsyncData<PlanProposalEntity?>(
      proposal.copyWith(status: PlanProposalStatus.applied, resolvedAt: now),
    );
    return plan;
  }

  Future<PlanProposalEntity?> reject({String? reason}) async {
    final PlanProposalEntity? proposal = state.asData?.value;
    if (proposal == null) return null;
    final PlanProposalEntity rejected = await ref
        .read(rejectPlanProposalUseCaseProvider)
        .call(proposal, reason: reason);
    state = AsyncData<PlanProposalEntity?>(rejected);
    return rejected;
  }
}

/// The canonical decision engine's schedule projection. Nexus must not run a
/// second planner with a different ordering or different evidence.
final adaptivePlanProvider = Provider<AsyncValue<List<TimeBlock>>>((Ref ref) {
  return ref.watch(siStateAggregationProvider).whenData((aggregation) {
    return List<TimeBlock>.unmodifiable(
      aggregation.planningDecision.plan.blocks,
    );
  });
});

/// Real blocks scheduled for the device's current local calendar day.
final todayTimeBlocksProvider = Provider<AsyncValue<List<TimeBlock>>>((
  Ref ref,
) {
  final DateTime now = ref.watch(adaptivePlanClockProvider)();
  return ref.watch(adaptivePlanProvider).whenData((List<TimeBlock> blocks) {
    final List<TimeBlock> today =
        blocks
            .where(
              (TimeBlock block) =>
                  block.start.year == now.year &&
                  block.start.month == now.month &&
                  block.start.day == now.day,
            )
            .toList(growable: false)
          ..sort(
            (TimeBlock first, TimeBlock second) =>
                first.start.compareTo(second.start),
          );
    return List<TimeBlock>.unmodifiable(today);
  });
});

/// The active block, or the nearest upcoming block, from today's real plan.
final nextTodayTimeBlockProvider = Provider<TimeBlock?>((Ref ref) {
  final DateTime now = ref.watch(adaptivePlanClockProvider)();
  final String? selectedTaskId = ref
      .watch(siStateAggregationProvider)
      .asData
      ?.value
      .planningDecision
      .selectedTask
      ?.id;
  return ref
      .watch(todayTimeBlocksProvider)
      .maybeWhen(
        data: (List<TimeBlock> blocks) {
          if (selectedTaskId != null) {
            for (final TimeBlock block in blocks) {
              if (!block.completed && block.taskId == selectedTaskId) {
                return block;
              }
            }
          }
          return ref
              .read(recommendNextBlockUseCaseProvider)
              .call(blocks: blocks, now: now);
        },
        orElse: () => null,
      );
});
