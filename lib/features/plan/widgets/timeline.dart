import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/features/plan/widgets/timeline_view.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

class Timeline extends StatelessWidget {
  const Timeline({
    super.key,
    required this.blocks,
    this.onCompleteTask,
    this.completingTaskIds = const <String>{},
  });

  final List<TimeBlock> blocks;
  final Future<void> Function(String taskId)? onCompleteTask;
  final Set<String> completingTaskIds;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.12)),
      ),
      child: TimelineView(
        blocks: blocks,
        onCompleteTask: onCompleteTask,
        completingTaskIds: completingTaskIds,
      ),
    );
  }
}
