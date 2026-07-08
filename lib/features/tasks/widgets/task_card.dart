import 'dart:math' as math;

import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/task_view.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TaskCard extends ConsumerWidget {
  const TaskCard({required this.task, this.onComplete, super.key});
  final TaskView task;
  final Future<void> Function(TaskView task)? onComplete;

  Color _priorityColor(int p) {
    if (p >= 5) return AppColors.recallRed;
    if (p >= 4) return Colors.deepOrangeAccent;
    if (p >= 3) return AppColors.memoryAmber;
    if (p >= 2) return AppColors.neonCyan;
    return Colors.white38;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color accent = _priorityColor(task.priority);

    return SmartPressable(
      onTap: () {
        ref.read(appFlowProvider.notifier).toSmartCoach();
      },
      pressedScale: 0.97,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF050D1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 16,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 52,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.7),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Tag(label: 'D${task.difficulty}', color: Colors.white24),
                      _Tag(
                        label: 'E${task.energyRequired}',
                        color: AppColors.neonCyan.withValues(alpha: 0.6),
                      ),
                      _Tag(
                        label: 'P${task.priority}',
                        color: accent.withValues(alpha: 0.8),
                      ),
                      const _Tag(label: '+10 XP', color: AppColors.memoryAmber),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CustomPaint(
                    painter: _PriorityRingPainter(
                      priority: task.priority,
                      color: accent,
                    ),
                    child: Center(
                      child: Text(
                        '${task.priority}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
                ),
                if (onComplete != null)
                  IconButton(
                    tooltip: 'Complete task',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.neonCyan,
                    ),
                    onPressed: () {
                      onComplete!(task);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, color: color, letterSpacing: 1),
      ),
    );
  }
}

class _PriorityRingPainter extends CustomPainter {
  const _PriorityRingPainter({required this.priority, required this.color});
  final int priority;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double r = size.width / 2 - 3;
    final double fill = (priority / 5).clamp(0.0, 1.0);

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = color.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    if (fill <= 0) return;

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      fill * 2 * math.pi,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      fill * 2 * math.pi,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_PriorityRingPainter old) =>
      old.priority != priority || old.color != color;
}
