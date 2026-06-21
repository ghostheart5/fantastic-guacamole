import 'package:flutter/material.dart';

import '../../../data/models/mission_model.dart';
import '../../../data/models/task_model.dart';

class MissionTile extends StatelessWidget {
  final MissionModel mission;
  final ValueChanged<String> onToggleTask;
  final ValueChanged<String> onDeleteTask;

  const MissionTile({
    super.key,
    required this.mission,
    required this.onToggleTask,
    required this.onDeleteTask,
  });

  @override
  Widget build(BuildContext context) {
    final int doneCount = mission.tasks
        .where((TaskModel task) => task.done)
        .length;

    return ExpansionTile(
      title: Text(mission.name),
      subtitle: Text('$doneCount/${mission.tasks.length} tasks done'),
      children: mission.tasks
          .map(
            (TaskModel task) => CheckboxListTile(
              value: task.done,
              onChanged: (_) => onToggleTask(task.id),
              title: Text(task.title),
              secondary: IconButton(
                tooltip: 'Delete task',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => onDeleteTask(task.id),
              ),
            ),
          )
          .toList(),
    );
  }
}
