import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_learning_repository.dart';
import 'package:fantastic_guacamole/domain/policies/learning_policy.dart';

class ApplyLearningFeedback {
  ApplyLearningFeedback(this.repository);

  final ILearningRepository repository;

  Future<LearningEntity> call({
    required bool success,
    required int difficulty,
  }) async {
    final LearningEntity current =
        await repository.getState() ?? const LearningEntity();
    final LearningEntity updated = LearningPolicy.applyFeedback(
      current: current,
      success: success,
      difficulty: difficulty,
    );
    await repository.saveState(updated);
    return updated;
  }
}
