import 'dart:math' as math;

import 'package:fantastic_guacamole/core/constants/app_colors.dart';
import 'package:fantastic_guacamole/core/widgets/smart_pressable.dart';
import 'package:fantastic_guacamole/engine/si/experimental/si_synthetic_soul_layer.dart';
import 'package:fantastic_guacamole/features/emotion/emotion_provider.dart';
import 'package:fantastic_guacamole/features/emotion/emotional_state.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final soulStateProvider = Provider<SoulState>((ref) {
  final si = ref.watch(siStateProvider);
  final traj = ref.watch(trajectorySummaryProvider);
  final emotion = ref.watch(emotionProvider);
  final mood = emotion == EmotionalState.anxious ||
          emotion == EmotionalState.fatigued ||
          emotion == EmotionalState.scattered
      ? 'stressed'
      : 'neutral';
  return const SyntheticSoulLayer().harmonize(
    presence: si.energy.clamp(0.0, 1.0),
    emergence: traj.momentum.clamp(0.0, 1.0),
    mood: mood,
    hasNarrative: traj.completedTasks > 0,
  );
});

class SoulMapScreen extends ConsumerWidget {
  const SoulMapScreen({super.key});

  static const _labels = [
    'Continuity',
    'Identity',
    'Emotional\nEvolution',
    'Personality\nGrowth',
    'Narrative\nPresence',
    'Connection',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soul = ref.watch(soulStateProvider);
    final values = [
      soul.continuity,
      soul.identityStrength,
      soul.emotionalEvolution,
      soul.personalityGrowth,
      soul.narrativePresence,
      soul.userConnection,
    ];

    final ranked = List.generate(6, (i) => MapEntry(i, values[i]))
      ..sort((a, b) => b.value.compareTo(a.value));
    final top2 = ranked.take(2).map((e) => _labels[e.key].replaceAll('\n', ' ')).toList();

    return AnimatedSystemBackground(
      backgroundAssetPath: 'assets/backgrounds/progression_bg.jpg',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SmartPressable(
                      onTap: () =>
                          ref.read(appFlowProvider.notifier).toCoach(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.neonCyan.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.neonCyan.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: AppColors.neonCyan,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 3,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.neonViolet,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonViolet.withValues(alpha: 0.8),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [AppColors.neonViolet, AppColors.neonCyan],
                          ).createShader(bounds),
                          child: const Text(
                            'SOUL MAP',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Text(
                          'YOUR INNER ARCHITECTURE',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 2,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Center(
                  child: SizedBox(
                    width: 300,
                    height: 300,
                    child: CustomPaint(
                      painter: _SoulRadarPainter(values: values),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _AxisLegend(labels: _labels, values: values),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF050D1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.neonViolet.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'STRONGEST DIMENSIONS',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 2.5,
                          color: AppColors.neonViolet,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...top2.map(
                        (label) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.neonViolet
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AxisLegend extends StatelessWidget {
  const _AxisLegend({required this.labels, required this.values});

  final List<String> labels;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: List.generate(
        labels.length,
        (i) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.neonViolet.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '${labels[i].replaceAll('\n', ' ')} ${(values[i] * 100).round()}%',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoulRadarPainter extends CustomPainter {
  const _SoulRadarPainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 30;
    const n = 6;

    // Background grid rings
    final gridPaint = Paint()
      ..color = AppColors.neonViolet.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int r = 1; r <= 4; r++) {
      final path = Path();
      for (int i = 0; i < n; i++) {
        final angle = (2 * math.pi * i / n) - math.pi / 2;
        final pt = Offset(
          center.dx + radius * (r / 4) * math.cos(angle),
          center.dy + radius * (r / 4) * math.sin(angle),
        );
        if (i == 0) path.moveTo(pt.dx, pt.dy);
        else path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Axis lines
    final axisPaint = Paint()
      ..color = AppColors.neonViolet.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    for (int i = 0; i < n; i++) {
      final angle = (2 * math.pi * i / n) - math.pi / 2;
      canvas.drawLine(
        center,
        Offset(
          center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle),
        ),
        axisPaint,
      );
    }

    // Filled data polygon
    final fillPaint = Paint()
      ..color = AppColors.neonViolet.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = AppColors.neonViolet.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final glowPaint = Paint()
      ..color = AppColors.neonViolet.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final dataPath = Path();
    for (int i = 0; i < n; i++) {
      final angle = (2 * math.pi * i / n) - math.pi / 2;
      final v = values[i].clamp(0.0, 1.0);
      final pt = Offset(
        center.dx + radius * v * math.cos(angle),
        center.dy + radius * v * math.sin(angle),
      );
      if (i == 0) dataPath.moveTo(pt.dx, pt.dy);
      else dataPath.lineTo(pt.dx, pt.dy);
    }
    dataPath.close();

    canvas.drawPath(dataPath, fillPaint);
    canvas.drawPath(dataPath, glowPaint);
    canvas.drawPath(dataPath, strokePaint);

    // Axis labels
    const labelStyle = TextStyle(
      color: Color(0xFF9B8AFB),
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );
    final labels = [
      'Continuity',
      'Identity',
      'Emotional\nEvolution',
      'Personality\nGrowth',
      'Narrative\nPresence',
      'Connection',
    ];
    for (int i = 0; i < n; i++) {
      final angle = (2 * math.pi * i / n) - math.pi / 2;
      final labelRadius = radius + 22;
      final lx = center.dx + labelRadius * math.cos(angle);
      final ly = center.dy + labelRadius * math.sin(angle);
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: labelStyle),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 70);
      tp.paint(
        canvas,
        Offset(lx - tp.width / 2, ly - tp.height / 2),
      );
    }

    // Dot at each vertex
    final dotPaint = Paint()
      ..color = AppColors.neonViolet
      ..style = PaintingStyle.fill;
    for (int i = 0; i < n; i++) {
      final angle = (2 * math.pi * i / n) - math.pi / 2;
      final v = values[i].clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(
          center.dx + radius * v * math.cos(angle),
          center.dy + radius * v * math.sin(angle),
        ),
        3.5,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_SoulRadarPainter old) => old.values != values;
}
