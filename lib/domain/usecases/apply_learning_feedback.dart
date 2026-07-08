import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_learning_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/domain/policies/learning_policy.dart';

class ApplyLearningFeedback {
  ApplyLearningFeedback(this.repository, {this.siRepo});

  final ILearningRepository repository;
  final ISiRepository? siRepo;

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

    final ISiRepository? si = siRepo;
    if (si != null && success) {
      final siState = await si.getCurrentState();
      if (siState != null) {
        await si.saveState(siState.withConfidenceDelta(0.02));
      }
    }

    return updated;
  }
}
