import 'package:fantastic_guacamole/domain/entities/plan_entity.dart';
import 'package:fantastic_guacamole/domain/entities/plan_proposal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_plan_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/create_plan.dart';
import 'package:fantastic_guacamole/domain/usecases/get_plan.dart';
import 'package:fantastic_guacamole/domain/usecases/update_plan.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the planned/alternate persisted planner path. See [IPlanRepository].
void main() {
  late _FakePlanRepository repository;

  PlanEntity planFor(DateTime date) => PlanEntity(
    id: 'plan-1',
    date: date,
    blocks: <TimeBlock>[
      TimeBlock(
        id: 'block-1',
        taskId: 'task-1',
        title: 'Deep work',
        start: date.add(const Duration(hours: 9)),
        end: date.add(const Duration(hours: 10)),
      ),
    ],
  );

  setUp(() => repository = _FakePlanRepository());

  group('CreatePlan', () {
    test('persists the plan and returns it', () async {
      final PlanEntity plan = planFor(DateTime.utc(2026, 7, 6));

      final PlanEntity created = await CreatePlan(repository).call(plan);

      expect(created.id, 'plan-1');
      expect(repository.saved.single.id, 'plan-1');
      expect(repository.saved.single.blocks, hasLength(1));
    });
  });

  group('GetPlan', () {
    test('returns the plan stored for that date', () async {
      final DateTime date = DateTime.utc(2026, 7, 6);
      await CreatePlan(repository).call(planFor(date));

      final PlanEntity? found = await GetPlan(repository).call(date);

      expect(found, isNotNull);
      expect(found!.id, 'plan-1');
      expect(found.blocks.single.title, 'Deep work');
    });

    test('returns null when no plan exists for that date', () async {
      final PlanEntity? found = await GetPlan(
        repository,
      ).call(DateTime.utc(2026, 12, 25));

      expect(found, isNull);
    });
  });

  group('UpdatePlan', () {
    test('returns the persisted object, not the stale input', () async {
      final DateTime date = DateTime.utc(2026, 7, 6);
      final PlanEntity plan = planFor(date);
      final DateTime updatedAt = DateTime.utc(2026, 7, 6, 18, 30);

      final PlanEntity result = await UpdatePlan(
        repository,
      ).call(plan, updatedAt: updatedAt);

      expect(
        result.updatedAt,
        updatedAt,
        reason: 'the returned object must carry the stamp that was persisted',
      );
      expect(
        result.updatedAt,
        repository.saved.single.updatedAt,
        reason: 'returned and stored objects must agree',
      );
      expect(plan.updatedAt, isNull, reason: 'the input is not mutated');
    });

    test('stamps updatedAt even when the caller supplies none', () async {
      final PlanEntity result = await UpdatePlan(
        repository,
      ).call(planFor(DateTime.utc(2026, 7, 6)));

      expect(result.updatedAt, isNotNull);
    });

    test('a round trip preserves every block field', () async {
      final DateTime date = DateTime.utc(2026, 7, 6);
      final PlanEntity updated = await UpdatePlan(
        repository,
      ).call(planFor(date), updatedAt: DateTime.utc(2026, 7, 6, 18));

      final PlanEntity? reloaded = await GetPlan(repository).call(date);

      expect(reloaded!.blocks.single.id, updated.blocks.single.id);
      expect(reloaded.blocks.single.taskId, updated.blocks.single.taskId);
      expect(reloaded.blocks.single.title, updated.blocks.single.title);
      expect(reloaded.blocks.single.start, updated.blocks.single.start);
      expect(reloaded.blocks.single.end, updated.blocks.single.end);
      expect(reloaded.blocks.single.completed, updated.blocks.single.completed);
    });
  });
}

class _FakePlanRepository implements IPlanRepository {
  final List<PlanEntity> saved = <PlanEntity>[];
  final Map<String, PlanProposalEntity> proposals =
      <String, PlanProposalEntity>{};

  @override
  Future<PlanEntity?> getPlan(DateTime date) async {
    for (final PlanEntity plan in saved) {
      if (plan.date == date) return plan;
    }
    return null;
  }

  @override
  Future<void> savePlan(PlanEntity plan) async {
    final int index = saved.indexWhere((PlanEntity p) => p.date == plan.date);
    if (index >= 0) {
      saved[index] = plan;
    } else {
      saved.add(plan);
    }
  }

  @override
  Future<PlanProposalEntity?> getProposal(String id) async => proposals[id];

  @override
  Future<void> saveProposal(PlanProposalEntity proposal) async {
    proposals[proposal.id] = proposal;
  }

  @override
  Future<void> applyProposal({
    required PlanProposalEntity proposal,
    required PlanEntity plan,
  }) async {
    await saveProposal(proposal);
    await savePlan(plan);
  }
}
