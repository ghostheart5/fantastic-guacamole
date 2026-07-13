import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/features/plan/widgets/time_block_widget.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

class TimelineView extends StatelessWidget {
  const TimelineView({
    super.key,
    required this.blocks,
    this.onCompleteTask,
    this.completingTaskIds = const <String>{},
  });

  final List<TimeBlock> blocks;
  final Future<void> Function(String taskId)? onCompleteTask;
  final Set<String> completingTaskIds;

  Color _blockColor(int index) {
    const List<Color> colors = <Color>[
      AppColors.neonCyan,
      AppColors.neonViolet,
      AppColors.memoryAmber,
      AppColors.recallRed,
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: blocks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final TimeBlock block = blocks[index];
        final String start =
            '${block.start.hour}:${block.start.minute.toString().padLeft(2, '0')}';
        final String end =
            '${block.end.hour}:${block.end.minute.toString().padLeft(2, '0')}';
        return TimeBlockWidget(
          taskId: block.taskId,
          title: block.title,
          start: start,
          end: end,
          accent: _blockColor(index),
          completed: block.completed,
          onCompleteTask: onCompleteTask,
          isCompleting: completingTaskIds.contains(block.taskId),
        );
      },
    );
  }
}
