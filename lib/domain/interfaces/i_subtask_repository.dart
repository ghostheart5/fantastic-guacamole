import 'package:fantastic_guacamole/domain/entities/subtask_entity.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Goals/tasks
///
/// Bound to SubtaskRepository.
abstract class ISubtaskRepository {
  List<SubtaskEntity> getSubtasks();
  Future<void> saveSubtask(SubtaskEntity subtask);
  Future<void> saveSubtasks(List<SubtaskEntity> subtasks);
  Future<void> deleteSubtask(String id);
}
