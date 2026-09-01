import 'package:fantastic_guacamole/data/repositories/learning_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/decision_observation_entity.dart';
import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SecureStore store;
  late LearningRepository repository;

  setUp(() {
    store = SecureStore(backend: InMemorySecureStoreBackend());
    repository = LearningRepository(store);
  });

  test(
    'persists stable task affinity and typed outcome observations',
    () async {
      final LearningEntity state = LearningEntity(completed: 2, skipped: 1)
          .recordObservation(
            DecisionObservationEntity(
              id: 'observation-1',
              type: DecisionObservationType.taskCompleted,
              timestamp: DateTime.utc(2026, 8, 17, 12),
              source: 'task_completion',
              taskId: 'task-1',
            ),
          );

      await repository.saveState(state);
      final LearningEntity? restored = await repository.getState();

      expect(restored, isNotNull);
      expect(restored!.taskAffinity['task-1'], closeTo(.6, .0001));
      expect(restored.observations, hasLength(1));
      expect(restored.observations.single.taskId, 'task-1');
      expect(
        restored.observations.single.type,
        DecisionObservationType.taskCompleted,
      );
    },
  );

  test('corrupt JSON is preserved and surfaced as no learned state', () async {
    await store.writeString('learning_state_v1', '{not-json');

    expect(await repository.getState(), isNull);
    expect(await store.readString('learning_state_v1'), '{not-json');
  });
}
