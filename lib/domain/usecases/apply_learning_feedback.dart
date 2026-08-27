import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';
import 'package:fantastic_guacamole/domain/entities/decision_observation_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_learning_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/domain/policies/learning_policy.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Learning/adaptation
///
/// Registered as applyLearningFeedbackUseCaseProvider. Repository is real; not
/// yet auto-invoked from completion/skip.
class ApplyLearningFeedback {
  ApplyLearningFeedback(this.repository, {this.siRepo});

  final ILearningRepository repository;
  final ISiRepository? siRepo;

  Future<LearningEntity> call({
    required bool success,
    required int difficulty,
    String? taskId,
    String source = 'learning_feedback',
  }) async {
    final LearningEntity current =
        await repository.getState() ?? const LearningEntity();
    final LearningEntity weighted = LearningPolicy.applyFeedback(
      current: current,
      success: success,
      difficulty: difficulty,
    );
    final DateTime observedAt = DateTime.now().toUtc();
    final LearningEntity updated = weighted.recordObservation(
      DecisionObservationEntity(
        id: '$source-${observedAt.microsecondsSinceEpoch}',
        type: success
            ? DecisionObservationType.taskCompleted
            : DecisionObservationType.taskSkipped,
        timestamp: observedAt,
        source: source,
        taskId: taskId,
      ),
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
