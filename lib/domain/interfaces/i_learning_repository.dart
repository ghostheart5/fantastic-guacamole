import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Learning/adaptation
///
/// Adaptive learning weights for the planner.
///
/// `LearningRepository` implements this contract and is bound in DI. Task
/// completion, task skip, and decision-outcome recording invoke the shipping
/// learning path. `UpdateLearningState` remains a separately classified helper
/// without a production caller.
abstract class ILearningRepository {
  Future<LearningEntity?> getState();
  Future<void> saveState(LearningEntity state);
}
