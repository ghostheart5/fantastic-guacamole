import 'package:fantastic_guacamole/domain/entities/plan_proposal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 20, 9);

  TimeBlock block({String id = 'block-1', String taskId = 'task-1'}) =>
      TimeBlock(
        id: id,
        taskId: taskId,
        title: 'Focused work',
        description: 'Schema-backed preview',
        start: now,
        end: now.add(const Duration(minutes: 30)),
      );

  test('preview proposal strictly round-trips through schema version one', () {
    final PlanProposalEntity proposal = PlanProposalEntity(
      id: 'proposal-1',
      date: now,
      blocks: <TimeBlock>[block()],
      generatedAt: now,
      evidenceSources: const <String>['tasks', 'calendar'],
      sourceDecisionId: 'decision-1',
    );
    proposal.validate();

    final PlanProposalEntity decoded = PlanProposalEntity.fromJson(
      proposal.toJson(),
    );

    expect(decoded.schemaVersion, PlanProposalEntity.currentSchemaVersion);
    expect(decoded.id, proposal.id);
    expect(decoded.blocks.single.description, 'Schema-backed preview');
    expect(decoded.status, PlanProposalStatus.preview);
  });

  test('resolved proposal requires a resolution timestamp', () {
    expect(
      () => PlanProposalEntity(
        id: 'proposal-1',
        date: now,
        blocks: <TimeBlock>[block()],
        generatedAt: now,
        status: PlanProposalStatus.applied,
      ).validate(),
      throwsFormatException,
    );
  });

  test('proposal rejects duplicate blocks and invalid conflict references', () {
    expect(
      () => PlanProposalEntity(
        id: 'proposal-1',
        date: now,
        blocks: <TimeBlock>[
          block(),
          block(taskId: 'task-2'),
        ],
        generatedAt: now,
      ).validate(),
      throwsFormatException,
    );

    expect(
      () => PlanProposalEntity(
        id: 'proposal-1',
        date: now,
        blocks: <TimeBlock>[block()],
        generatedAt: now,
        conflicts: const <PlanConflict>[
          PlanConflict(
            firstBlockId: 'block-1',
            secondBlockId: 'missing-block',
            reason: 'Invalid reference',
          ),
        ],
      ).validate(),
      throwsFormatException,
    );
  });

  test('proposal rejects unknown versions and unknown JSON fields', () {
    final PlanProposalEntity proposal = PlanProposalEntity(
      id: 'proposal-1',
      date: now,
      blocks: <TimeBlock>[block()],
      generatedAt: now,
    );
    final Map<String, Object?> wrongVersion = proposal.toJson()
      ..['schemaVersion'] = 2;
    expect(
      () => PlanProposalEntity.fromJson(wrongVersion),
      throwsFormatException,
    );

    final Map<String, Object?> unknownField = proposal.toJson()
      ..['executeNow'] = true;
    expect(
      () => PlanProposalEntity.fromJson(unknownField),
      throwsFormatException,
    );
  });

  test('proposal rejects malformed nested and optional fields', () {
    final PlanProposalEntity proposal = PlanProposalEntity(
      id: 'proposal-1',
      date: now,
      blocks: <TimeBlock>[block()],
      generatedAt: now,
    );
    final Map<String, Object?> malformedBlock = proposal.toJson();
    final Map<String, Object?> nested = Map<String, Object?>.from(
      (malformedBlock['blocks']! as List<Object?>).single
          as Map<String, Object?>,
    )..['executeNow'] = true;
    malformedBlock['blocks'] = <Object?>[nested];
    expect(
      () => PlanProposalEntity.fromJson(malformedBlock),
      throwsFormatException,
    );

    final Map<String, Object?> malformedOptional = proposal.toJson()
      ..['sourceDecisionId'] = 7;
    expect(
      () => PlanProposalEntity.fromJson(malformedOptional),
      throwsFormatException,
    );

    expect(
      () => PlanConflict.fromJson(<String, Object?>{
        'firstBlockId': 'block-1',
        'secondBlockId': 'block-2',
        'reason': 'Overlap',
        'unexpected': true,
      }),
      throwsFormatException,
    );
  });
}
