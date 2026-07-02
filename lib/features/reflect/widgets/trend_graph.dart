import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class TrendPoint {
  const TrendPoint({required this.label, required this.value});

  final String label; // e.g. "Mon"
  final double value; // 0.0–1.0
}

class TrendGraph extends StatelessWidget {
  const TrendGraph({
    super.key,
    required this.points,
    this.accentColor = AppColors.neonCyan,
    this.label = 'TREND',
  });

  final List<TrendPoint> points;
  final Color accentColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 2,
                height: 14,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.5,
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (points.isNotEmpty)
                Text(
                  '${(points.last.value * 100).round()}%',
                  style: TextStyle(
                    fontSize: 13,
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (points.isEmpty)
            const SizedBox(
              height: 80,
              child: Center(
                child: Text(
                  'NO DATA YET',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    color: Colors.white24,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 80,
              child: _TrendPainter(points: points, accentColor: accentColor),
            ),
          const SizedBox(height: 8),
          if (points.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: points
                  .map(
                    (p) => Text(
                      p.label,
                      style: const TextStyle(
                        fontSize: 9,
                        letterSpacing: 0.5,
                        color: Colors.white38,
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _TrendPainter extends StatelessWidget {
  const _TrendPainter({required this.points, required this.accentColor});

  final List<TrendPoint> points;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GraphPainter(points: points, accentColor: accentColor),
      size: const Size(double.infinity, 80),
    );
  }
}

class _GraphPainter extends CustomPainter {
  const _GraphPainter({required this.points, required this.accentColor});

  final List<TrendPoint> points;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) {
      _drawSinglePoint(canvas, size);
      return;
    }

    final linePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withValues(alpha: 0.2),
          accentColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final dotPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    final coords = _buildCoords(size);
    final linePath = Path();
    final fillPath = Path();

    linePath.moveTo(coords[0].dx, coords[0].dy);
    fillPath.moveTo(coords[0].dx, size.height);
    fillPath.lineTo(coords[0].dx, coords[0].dy);

    for (int i = 1; i < coords.length; i++) {
      final prev = coords[i - 1];
      final curr = coords[i];
      final cpX = (prev.dx + curr.dx) / 2;
      linePath.cubicTo(cpX, prev.dy, cpX, curr.dy, curr.dx, curr.dy);
      fillPath.cubicTo(cpX, prev.dy, cpX, curr.dy, curr.dx, curr.dy);
    }

    fillPath.lineTo(coords.last.dx, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);

    for (final pt in coords) {
      canvas.drawCircle(pt, 3, dotPaint);
      canvas.drawCircle(
        pt,
        3,
        Paint()
          ..color = const Color(0xFF050D1A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  List<Offset> _buildCoords(Size size) {
    final n = points.length;
    return List.generate(n, (i) {
      final x = n == 1 ? size.width / 2 : i / (n - 1) * size.width;
      final y =
          size.height -
          (points[i].value.clamp(0.0, 1.0) * size.height * 0.85 +
              size.height * 0.05);
      return Offset(x, y);
    });
  }

  void _drawSinglePoint(Canvas canvas, Size size) {
    final value = points.first.value.clamp(0.0, 1.0);
    final x = size.width / 2;
    final y = size.height - (value * size.height * 0.85 + size.height * 0.05);
    final dotPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(x, y), 5, dotPaint);
  }

  @override
  bool shouldRepaint(_GraphPainter old) =>
      old.points != points || old.accentColor != accentColor;
}
