import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_learning_repository.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Learning/adaptation
///
/// Registered as updateLearningStateUseCaseProvider.
class UpdateLearningState {
  UpdateLearningState(this.repository);

  final ILearningRepository repository;

  Future<void> call(LearningEntity state) {
    return repository.saveState(state);
  }
}
