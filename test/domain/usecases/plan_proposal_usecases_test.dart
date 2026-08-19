import 'package:fantastic_guacamole/domain/entities/plan_entity.dart';
import 'package:fantastic_guacamole/domain/entities/plan_proposal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_plan_repository.dart';
import 'package:fantastic_guacamole/domain/planning/planner_input.dart';
import 'package:fantastic_guacamole/domain/usecases/generate_adaptive_plan.dart';
import 'package:fantastic_guacamole/domain/usecases/plan_proposal_usecases.dart';
import 'package:fantastic_guacamole/engine/planning/calendar_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _PlanRepository implements IPlanRepository {
  PlanEntity? plan;
  PlanProposalEntity? proposal;

  @override
  Future<void> applyProposal({
    required PlanProposalEntity proposal,
    required PlanEntity plan,
  }) async {
    this.proposal = proposal;
    this.plan = plan;
  }

  @override
  Future<PlanEntity?> getPlan(DateTime date) async => plan;

  @override
  Future<PlanProposalEntity?> getProposal(String id) async => proposal;

  @override
  Future<void> savePlan(PlanEntity value) async => plan = value;

  @override
  Future<void> saveProposal(PlanProposalEntity value) async => proposal = value;
}

PlannerInput _input(String id) => PlannerInput(
  id: id,
  title: 'Task $id',
  priority: 4,
  difficulty: 3,
  energyRequired: 3,
  isCompleted: false,
  isCanceled: false,
  prerequisiteIds: const <String>[],
  recurrenceRule: RecurrenceRule.none,
  estimatedDuration: const Duration(minutes: 30),
);

void main() {
  final DateTime now = DateTime.utc(2026, 8, 19, 9);
  late _PlanRepository repository;

  setUp(() => repository = _PlanRepository());

  test('preview is durable, evidence-backed, and feasible', () async {
    final PlanProposalEntity proposal =
        await PreviewAdaptivePlan(
          GenerateAdaptivePlan(CalendarService()),
          repository,
        )(
          inputs: <PlannerInput>[_input('a'), _input('b')],
          energy: 0.6,
          startTime: now,
          now: now,
          id: 'proposal-1',
          sourceDecisionId: 'decision-1',
        );

    expect(proposal.status, PlanProposalStatus.preview);
    expect(proposal.isFeasible, isTrue);
    expect(proposal.evidenceSources, contains('tasks'));
    expect(repository.proposal?.id, 'proposal-1');
  });

  test('apply persists the plan and resolved proposal together', () async {
    final PlanProposalEntity proposal =
        await PreviewAdaptivePlan(
          GenerateAdaptivePlan(CalendarService()),
          repository,
        )(
          inputs: <PlannerInput>[_input('a')],
          energy: 0.6,
          startTime: now,
          now: now,
          id: 'proposal-1',
        );

    final PlanEntity plan = await ApplyPlanProposal(repository)(
      proposal,
      now: now.add(const Duration(minutes: 1)),
    );

    expect(plan.blocks, isNotEmpty);
    expect(repository.proposal?.status, PlanProposalStatus.applied);
    expect(repository.plan?.id, proposal.id);
  });

  test('reject records the reason without applying the plan', () async {
    final PlanProposalEntity proposal =
        await PreviewAdaptivePlan(
          GenerateAdaptivePlan(CalendarService()),
          repository,
        )(
          inputs: <PlannerInput>[_input('a')],
          energy: 0.6,
          startTime: now,
          now: now,
          id: 'proposal-1',
        );

    final PlanProposalEntity rejected = await RejectPlanProposal(repository)(
      proposal,
      reason: 'Keep the morning open',
      now: now,
    );

    expect(rejected.status, PlanProposalStatus.rejected);
    expect(rejected.rejectionReason, 'Keep the morning open');
    expect(repository.plan, isNull);
  });
}
