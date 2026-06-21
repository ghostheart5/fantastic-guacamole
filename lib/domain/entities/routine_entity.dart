import 'task_entity.dart';

class RoutineEntity {
  final String id;
  final String name;
  final List<TaskEntity> tasks;

  const RoutineEntity({
    required this.id,
    required this.name,
    required this.tasks,
  });
}
