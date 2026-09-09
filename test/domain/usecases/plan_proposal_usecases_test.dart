import 'package:fantastic_guacamole/domain/entities/plan_entity.dart';
import 'package:fantastic_guacamole/domain/entities/plan_proposal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_plan_repository.dart';
import 'package:fantastic_guacamole/domain/planning/planner_input.dart';
import 'package:fantastic_guacamole/domain/ports/i_adaptive_plan_generator.dart';
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

class _ConflictingGenerator implements IAdaptivePlanGenerator {
  const _ConflictingGenerator(this.blocks);
  final List<TimeBlock> blocks;

  @override
  List<TimeBlock> generateAdaptivePlan({
    required List<PlannerInput> inputs,
    required double energy,
    DateTime? startTime,
    AdaptivePlanPolicy policy = const AdaptivePlanPolicy(),
  }) => blocks;
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

  test(
    'overlapping generated work remains a reviewable, unapplied preview',
    () async {
      final TimeBlock first = TimeBlock(
        id: 'first',
        taskId: 'a',
        title: 'First task',
        start: now,
        end: now.add(const Duration(hours: 1)),
      );
      final TimeBlock second = TimeBlock(
        id: 'second',
        taskId: 'b',
        title: 'Second task',
        start: now.add(const Duration(minutes: 30)),
        end: now.add(const Duration(minutes: 90)),
      );
      final PlanProposalEntity proposal =
          await PreviewAdaptivePlan(
            GenerateAdaptivePlan(
              _ConflictingGenerator(<TimeBlock>[second, first]),
            ),
            repository,
          )(
            inputs: <PlannerInput>[_input('a'), _input('b')],
            energy: 0.6,
            startTime: now,
            now: now,
            id: 'conflicted',
          );

      expect(proposal.isFeasible, isFalse);
      expect(proposal.conflicts, hasLength(1));
      expect(proposal.conflicts.single.firstBlockId, 'first');
      expect(proposal.conflicts.single.secondBlockId, 'second');
      expect(
        proposal.conflicts.single.reason,
        'First task overlaps Second task.',
      );
      expect(repository.proposal, same(proposal));
      await expectLater(
        ApplyPlanProposal(repository)(proposal),
        throwsStateError,
      );
      expect(repository.plan, isNull);
      expect(repository.proposal, same(proposal));
    },
  );

  for (final PlanProposalStatus status in <PlanProposalStatus>[
    PlanProposalStatus.applied,
    PlanProposalStatus.rejected,
  ]) {
    test(
      'resolved $status proposal cannot be applied or rejected again',
      () async {
        final PlanProposalEntity resolved = PlanProposalEntity(
          id: 'resolved',
          date: now,
          blocks: const <TimeBlock>[],
          generatedAt: now,
          status: status,
          resolvedAt: now,
        );
        repository.proposal = resolved;
        await expectLater(
          ApplyPlanProposal(repository)(resolved),
          throwsStateError,
        );
        await expectLater(
          RejectPlanProposal(repository)(resolved),
          throwsStateError,
        );
        expect(repository.plan, isNull);
        expect(repository.proposal, same(resolved));
      },
    );
  }

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
