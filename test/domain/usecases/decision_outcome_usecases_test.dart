import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_decision_outcome_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/decision_outcome_usecases.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('records explicit recommendation rejection feedback', () async {
    final _FakeDecisionOutcomeRepository repository =
        _FakeDecisionOutcomeRepository();
    final DecisionOutcomeEntity outcome = DecisionOutcomeEntity(
      decisionId: 'si-a1',
      kind: DecisionOutcomeKind.rejected,
      surface: 'smart_planner',
      recordedAt: DateTime.utc(2026, 8, 19),
      modelVersion: 'si-core-v1',
      recommendationConfidence: 0.7,
      detail: 'Conflicts with a fixed commitment.',
    );

    await RecordDecisionOutcome(repository)(outcome);

    expect(
      (await GetDecisionOutcomes(repository)()).single.kind,
      DecisionOutcomeKind.rejected,
    );
  });

  test('rejects feedback without decision provenance', () async {
    final _FakeDecisionOutcomeRepository repository =
        _FakeDecisionOutcomeRepository();
    final DecisionOutcomeEntity outcome = DecisionOutcomeEntity(
      decisionId: ' ',
      kind: DecisionOutcomeKind.rejected,
      surface: 'smart_planner',
      recordedAt: DateTime.utc(2026, 8, 19),
      modelVersion: 'si-core-v1',
      recommendationConfidence: 0.7,
    );

    expect(
      () => RecordDecisionOutcome(repository)(outcome),
      throwsArgumentError,
    );
  });
}

class _FakeDecisionOutcomeRepository implements IDecisionOutcomeRepository {
  final List<DecisionOutcomeEntity> values = <DecisionOutcomeEntity>[];

  @override
  Future<List<DecisionOutcomeEntity>> load() async => List.unmodifiable(values);

  @override
  Future<void> record(DecisionOutcomeEntity outcome) async =>
      values.add(outcome);
}
