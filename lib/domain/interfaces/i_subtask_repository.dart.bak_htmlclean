import 'package:fantastic_guacamole/domain/entities/subtask_entity.dart';

abstract class ISubtaskRepository {
  List<SubtaskEntity> getSubtasks();
  Future<void> saveSubtask(SubtaskEntity subtask);
  Future<void> saveSubtasks(List<SubtaskEntity> subtasks);
  Future<void> deleteSubtask(String id);
}
