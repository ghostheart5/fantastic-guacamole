import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:fantastic_guacamole/core/constants/app_colors.dart';

class EnergyCard extends StatelessWidget {
  const EnergyCard({super.key, required this.energy});
  final double energy;

  Color get _color {
    if (energy >= 0.75) return Colors.greenAccent;
    if (energy >= 0.45) return AppColors.neonCyan;
    return Colors.orangeAccent;
  }

  String get _label {
    if (energy >= 0.75) return 'HIGH';
    if (energy >= 0.45) return 'MODERATE';
    return 'LOW';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: CustomPaint(
            painter: _EnergyArcPainter(energy: energy, color: _color),
            child: Center(
              child: Text(
                '${(energy * 100).round()}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _color,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: _color,
                    ),
                  ),
                  const Text(
                    ' ENERGY',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: energy,
                  minHeight: 4,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(_color),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EnergyArcPainter extends CustomPainter {
  const _EnergyArcPainter({required this.energy, required this.color});
  final double energy;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double r = size.width / 2 - 4;

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = color.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    if (energy <= 0) return;

    final double sweep = energy * 2 * math.pi * 0.85;

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
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
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_EnergyArcPainter old) =>
      old.energy != energy || old.color != color;
}
