import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Learning/adaptation
///
/// Adaptive learning weights for the planner.
///
/// PLANNED SURFACE: `LearningRepository` implements this and it is bound in DI,
/// so `ApplyLearningFeedback` / `UpdateLearningState` / `SkipTask` are all
/// constructible. What is NOT yet wired is automatic invocation: nothing calls
/// `ApplyLearningFeedback` from the task completion/skip flows, so the weights
/// only move when a caller runs the use cases explicitly. Turning that on
/// changes planner ordering and is a deliberate product decision.
abstract class ILearningRepository {
  Future<LearningEntity?> getState();
  Future<void> saveState(LearningEntity state);
}
