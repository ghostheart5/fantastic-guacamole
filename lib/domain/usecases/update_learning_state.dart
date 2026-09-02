import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_learning_repository.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Learning/adaptation
///
/// Registered as updateLearningStateUseCaseProvider, but has no production
/// caller. Shipping learning writes use ApplyLearningFeedback or SkipTask.
class UpdateLearningState {
  UpdateLearningState(this.repository);

  final ILearningRepository repository;

  Future<void> call(LearningEntity state) {
    return repository.saveState(state);
  }
}
