import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/data/models/time_block.dart';
import 'package:fantastic_guacamole/features/plan/widgets/timeline_view.dart';
import 'package:flutter/material.dart';

class Timeline extends StatelessWidget {
  const Timeline({super.key, required this.blocks});

  final List<TimeBlock> blocks;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.12)),
      ),
      child: TimelineView(blocks: blocks),
    );
  }
}
