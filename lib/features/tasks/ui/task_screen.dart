import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TaskScreen extends ConsumerWidget {
  const TaskScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TrajectorySummaryView summary = ref.watch(trajectorySummaryProvider);

    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgActivityArchive,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            children: [
              const Text(
                'TRAJECTORY ENGINE',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'PREDICTIVE GUIDANCE · TRAJECTORY SIGNALS · SI ALERTS',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white54,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 12),
              _CreatorTaskRedirectPanel(
                onTap: () => ref.read(appFlowProvider.notifier).toCreator(),
              ),
              const SizedBox(height: 12),
              _TrajectorySummaryCard(summary: summary),
              const SizedBox(height: 14),
              _PredictiveSiReportCard(summary: summary),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreatorTaskRedirectPanel extends StatelessWidget {
  const _CreatorTaskRedirectPanel({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.neonCyan.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'TASK CREATION',
            style: TextStyle(
              color: AppColors.neonCyan,
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'To keep creation consistent and avoid cross-module drift, new tasks are created in Creator only.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.neonCyan,
                foregroundColor: Colors.black,
              ),
              child: const Text('OPEN CREATOR'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrajectorySummaryCard extends StatelessWidget {
  const _TrajectorySummaryCard({required this.summary});

  final TrajectorySummaryView summary;

  @override
  Widget build(BuildContext context) {
    final double predictionProbability = summary.predictionProbability ?? 0.0;
    final String predictionExplanation =
        summary.predictionExplanation ??
        'Prediction details are unavailable right now.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TRAJECTORY SNAPSHOT',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white54,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricChip(label: 'PENDING', value: '${summary.pendingTasks}'),
              _MetricChip(
                label: 'COMPLETED',
                value: '${summary.completedTasks}',
              ),
              _MetricChip(label: 'LEVEL', value: 'L${summary.level}'),
              _MetricChip(label: 'STREAK', value: '${summary.streak}d'),
              _MetricChip(label: 'TODAY', value: '${summary.completedToday}'),
              _MetricChip(label: 'PRESSURE', value: '${summary.pressureIndex}'),
              _MetricChip(
                label: 'DIVERGENCE',
                value: '${summary.behaviorDivergence}%',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            summary.alert,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'XP ${summary.lastCompletionXp}  ·  Quality ${(summary.lastCompletionQuality * 100).round()}%  ·  Momentum ${(summary.momentum * 100).round()}%',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Adaptability ${(summary.adaptability * 100).round()}%',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (summary.hasPrediction) ...[
            const SizedBox(height: 12),
            Text(
              'Historical signal: ${summary.predictionOutcome} · ${(predictionProbability * 100).round()}%',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              predictionExplanation,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PredictiveSiReportCard extends StatelessWidget {
  const _PredictiveSiReportCard({required this.summary});

  final TrajectorySummaryView summary;

  @override
  Widget build(BuildContext context) {
    final double predictionProbability = summary.predictionProbability ?? 0.0;
    final String predictionExplanation =
        summary.predictionExplanation ??
        'Prediction details are unavailable right now.';
    final String forecast = summary.hasPrediction
        ? '${summary.predictionTitle}: historical signal ${summary.predictionOutcome} · ${(predictionProbability * 100).round()}%'
        : 'No historical signal yet. Using live trajectory signals.';
    final String guidance = summary.hasPrediction
        ? predictionExplanation
        : summary.alert;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PREDICTIVE SI REPORT',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white54,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            forecast,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            guidance,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricChip(
                label: 'ENERGY',
                value: '${(summary.energy * 100).round()}%',
              ),
              _MetricChip(
                label: 'MOMENTUM',
                value: '${(summary.momentum * 100).round()}%',
              ),
              _MetricChip(
                label: 'ADAPTABILITY',
                value: '${(summary.adaptability * 100).round()}%',
              ),
              _MetricChip(label: 'PRESSURE', value: '${summary.pressureIndex}'),
              _MetricChip(
                label: 'DIVERGENCE',
                value: '${summary.behaviorDivergence}%',
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Recommended next move: execute one high-confidence task to drop pressure and stabilize trajectory.',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              letterSpacing: 1.5,
              color: Colors.white38,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
