import 'package:fantastic_guacamole/data/models/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final tasksProvider = FutureProvider<List<Task>>((ref) async {
  final List<TaskEntity> tasks = await ref.read(getTasksUseCaseProvider).call();
  return tasks
      .map(
        (TaskEntity task) => Task(
          id: task.id,
          title: task.title,
          priority: task.priority,
          difficulty: task.difficulty,
          energyRequired: task.energyRequired,
        ),
      )
      .toList();
});
