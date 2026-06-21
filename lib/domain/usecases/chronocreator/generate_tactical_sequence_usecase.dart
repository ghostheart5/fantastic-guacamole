import '../../entities/task_entity.dart';
import '../../entities/tactical_sequence_entity.dart';

class GenerateTacticalSequenceUseCase {
  TacticalSequenceEntity call({
    required String id,
    required String missionId,
    required List<TaskEntity> tasks,
  }) {
    final List<TaskEntity> sorted = <TaskEntity>[...tasks]
      ..sort((TaskEntity a, TaskEntity b) => b.priority.compareTo(a.priority));

    return TacticalSequenceEntity(
      id: id,
      missionId: missionId,
      orderedTaskIds: sorted.map((TaskEntity t) => t.id).toList(),
    );
  }
}
