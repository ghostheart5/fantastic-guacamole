import 'dart:math' as math;

import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/features/progression/models/user_progress.dart';
import 'package:fantastic_guacamole/features/progression/widgets/progress_bar.dart';
import 'package:flutter/material.dart';

class LevelCard extends StatelessWidget {
  const LevelCard({super.key, required this.progress});

  final UserProgress progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.memoryAmber.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.memoryAmber.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: CustomPaint(
              painter: _LevelRingPainter(progress: progress.levelProgress),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${progress.level}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.memoryAmber,
                      ),
                    ),
                    const Text(
                      'LVL',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.5,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    progress.levelTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${progress.xpToNext} XP to Level ${progress.level + 1}',
                    style: const TextStyle(fontSize: 12, color: Colors.white38),
                  ),
                ),
                const SizedBox(height: 10),
                ProgressBar(
                  value: progress.levelProgress,
                  color: AppColors.memoryAmber,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelRingPainter extends CustomPainter {
  const _LevelRingPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 6;
    const color = AppColors.memoryAmber;

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = color.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );

    if (progress <= 0) return;

    final sweep = progress * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_LevelRingPainter old) => old.progress != progress;
}
