// CHRONOSPARK-CLASS: SHIPPING | Feature: Smart Planner proposals
import 'package:fantastic_guacamole/domain/entities/plan_entity.dart';
import 'package:fantastic_guacamole/domain/entities/plan_proposal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_plan_repository.dart';
import 'package:fantastic_guacamole/domain/planning/adaptive_plan_policy.dart';
import 'package:fantastic_guacamole/domain/planning/planner_input.dart';
import 'package:fantastic_guacamole/domain/usecases/generate_adaptive_plan.dart';

class PreviewAdaptivePlan {
  const PreviewAdaptivePlan(this._generate, this._repository);

  final GenerateAdaptivePlan _generate;
  final IPlanRepository _repository;

  Future<PlanProposalEntity> call({
    required List<PlannerInput> inputs,
    required double energy,
    DateTime? startTime,
    DateTime? now,
    String? id,
    String? sourceDecisionId,
    List<String> evidenceSources = const <String>['tasks', 'calendar'],
    AdaptivePlanPolicy policy = const AdaptivePlanPolicy(),
  }) async {
    final DateTime generatedAt = now ?? DateTime.now();
    final List<TimeBlock> blocks = _generate(
      inputs: inputs,
      energy: energy,
      startTime: startTime,
      policy: policy,
    );
    final PlanProposalEntity proposal = PlanProposalEntity(
      id: id ?? 'plan-proposal-${generatedAt.microsecondsSinceEpoch}',
      date: startTime ?? generatedAt,
      blocks: List<TimeBlock>.unmodifiable(blocks),
      generatedAt: generatedAt,
      conflicts: List<PlanConflict>.unmodifiable(_conflicts(blocks)),
      evidenceSources: List<String>.unmodifiable(evidenceSources),
      sourceDecisionId: sourceDecisionId,
    );
    proposal.validate();
    await _repository.saveProposal(proposal);
    return proposal;
  }

  List<PlanConflict> _conflicts(List<TimeBlock> blocks) {
    final List<TimeBlock> ordered = blocks.toList(growable: false)
      ..sort(
        (TimeBlock first, TimeBlock second) =>
            first.start.compareTo(second.start),
      );
    final List<PlanConflict> conflicts = <PlanConflict>[];
    for (int index = 0; index < ordered.length - 1; index++) {
      final TimeBlock first = ordered[index];
      final TimeBlock second = ordered[index + 1];
      if (first.end.isAfter(second.start)) {
        conflicts.add(
          PlanConflict(
            firstBlockId: first.id,
            secondBlockId: second.id,
            reason: '${first.title} overlaps ${second.title}.',
          ),
        );
      }
    }
    return conflicts;
  }
}

class ApplyPlanProposal {
  const ApplyPlanProposal(this._repository);

  final IPlanRepository _repository;

  Future<PlanEntity> call(PlanProposalEntity proposal, {DateTime? now}) async {
    proposal.validate();
    if (proposal.status != PlanProposalStatus.preview) {
      throw StateError('Only preview proposals can be applied.');
    }
    if (!proposal.isFeasible) {
      throw StateError('A proposal with schedule conflicts cannot be applied.');
    }
    final DateTime appliedAt = now ?? DateTime.now();
    final PlanEntity plan = PlanEntity(
      id: proposal.id,
      date: proposal.date,
      blocks: proposal.blocks,
      updatedAt: appliedAt,
    );
    final PlanProposalEntity applied = proposal.copyWith(
      status: PlanProposalStatus.applied,
      resolvedAt: appliedAt,
    );
    applied.validate();
    await _repository.applyProposal(proposal: applied, plan: plan);
    return plan;
  }
}

class RejectPlanProposal {
  const RejectPlanProposal(this._repository);

  final IPlanRepository _repository;

  Future<PlanProposalEntity> call(
    PlanProposalEntity proposal, {
    String? reason,
    DateTime? now,
  }) async {
    proposal.validate();
    if (proposal.status != PlanProposalStatus.preview) {
      throw StateError('Only preview proposals can be rejected.');
    }
    final PlanProposalEntity rejected = proposal.copyWith(
      status: PlanProposalStatus.rejected,
      rejectionReason: reason?.trim(),
      resolvedAt: now ?? DateTime.now(),
    );
    rejected.validate();
    await _repository.saveProposal(rejected);
    return rejected;
  }
}
