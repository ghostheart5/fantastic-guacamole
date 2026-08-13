import 'package:fantastic_guacamole/domain/entities/decision_observation_entity.dart';
import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DecisionObservationEntity preserves consumer fields through JSON', () {
    final DecisionObservationEntity observation = DecisionObservationEntity(
      id: 'observation-1',
      type: DecisionObservationType.taskSkipped,
      timestamp: DateTime.utc(2026, 8, 13, 12),
      source: 'test',
      taskId: 'task-1',
    );

    final DecisionObservationEntity restored =
        DecisionObservationEntity.fromJson(observation.toJson());
    expect(restored.id, observation.id);
    expect(restored.type, DecisionObservationType.taskSkipped);
    expect(restored.taskId, 'task-1');
    expect(DecisionObservationType.values, contains(DecisionObservationType.recommendationShown));
  });

  test('LearningState is the LearningEntity compatibility surface', () {
    final LearningEntity learning = const LearningState().recordObservation(
      type: DecisionObservationType.recommendationShown,
      taskId: 'task-1',
      source: 'decision',
      timestamp: DateTime.utc(2026, 8, 13, 12),
    ).recordRecommendationOutcome(
      taskId: 'task-1',
      accepted: true,
      timestamp: DateTime.utc(2026, 8, 13, 12, 1),
    );

    expect(learning.taskAffinity['task-1'], greaterThan(0.5));
    expect(learning.observations, hasLength(2));
    expect(learning.wasRecentlyRecommended('task-1', at: DateTime.utc(2026, 8, 13, 13)), isTrue);
    expect(LearningEntity.fromJson(learning.toJson()).observations, hasLength(2));
  });

  test('TimeBlock validation accepts valid scheduling blocks and rejects invalid ones', () {
    final TimeBlock valid = TimeBlock(
      id: 'block-1',
      taskId: 'task-1',
      title: 'Focus',
      start: DateTime.utc(2026, 8, 13, 9),
      end: DateTime.utc(2026, 8, 13, 10),
    );
    expect(valid.validate, returnsNormally);

    final TimeBlock invalid = valid.copyWith(end: valid.start);
    expect(invalid.validate, throwsStateError);
  });
}
