import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_learning_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/policies/learning_policy.dart';

class SkipTask {
  SkipTask(this.taskRepository, this.learningRepository);

  final ITaskRepository taskRepository;
  final ILearningRepository learningRepository;

  Future<LearningEntity> call({
    required String taskId,
    required int difficulty,
  }) async {
    final task = await taskRepository.getTaskById(taskId);
    if (task == null) {
      throw StateError('Task not found');
    }

    final LearningEntity current =
        await learningRepository.getState() ?? const LearningEntity();
    final LearningEntity updated = LearningPolicy.applyFeedback(
      current: current,
      success: false,
      difficulty: difficulty,
    );
    await learningRepository.saveState(updated);
    return updated;
  }
}
