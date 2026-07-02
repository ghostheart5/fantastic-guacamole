import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class FocusTimer extends StatelessWidget {
  const FocusTimer({super.key, required this.seconds, required this.progress});

  final int seconds;
  final double progress;

  String _format(int s) {
    final String min = (s ~/ 60).toString().padLeft(2, '0');
    final String sec = (s % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'TIME REMAINING',
          style: TextStyle(fontSize: 10, letterSpacing: 2.5, color: Colors.white38),
        ),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _format(seconds),
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w200,
              letterSpacing: 6,
              color: AppColors.neonCyan,
            ),
          ),
        ),
        const SizedBox(height: 24),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.neonCyan),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${(progress * 100).round()}% complete',
          style: const TextStyle(fontSize: 11, color: Colors.white38, letterSpacing: 1),
        ),
      ],
    );
  }
}
