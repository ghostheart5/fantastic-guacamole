import 'package:fantastic_guacamole/features/tasks/widgets/task_card.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/task_view.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TaskScreen extends ConsumerWidget {
  const TaskScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);
    final TrajectorySummaryView summary = ref.watch(trajectorySummaryProvider);

    return AnimatedSystemBackground(
      backgroundAssetPath: 'assets/backgrounds/tasks_bg.png',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: tasksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (tasks) {
              return CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'TRAJECTORY ENGINE',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 6)),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'PREDICTIVE BEHAVIOR · HABITS · SI ALERTS',
                        style: TextStyle(fontSize: 10, color: Colors.white54, letterSpacing: 1.8),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 14)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _TrajectorySummaryCard(summary: summary),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 14)),
                  if (tasks.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _PredictiveSiReportCard(summary: summary),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TaskCard(task: TaskView.fromTask(tasks[index])),
                          );
                        }, childCount: tasks.length),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
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
        summary.predictionExplanation ?? 'Prediction details are unavailable right now.';

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
              _MetricChip(label: 'COMPLETED', value: '${summary.completedTasks}'),
              _MetricChip(label: 'LEVEL', value: 'L${summary.level}'),
              _MetricChip(label: 'STREAK', value: '${summary.streak}d'),
              _MetricChip(label: 'TODAY', value: '${summary.completedToday}'),
              _MetricChip(label: 'PRESSURE', value: '${summary.pressureIndex}'),
              _MetricChip(label: 'DIVERGENCE', value: '${summary.behaviorDivergence}%'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            summary.alert,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            'XP ${summary.lastSessionXp}  ·  Quality ${(summary.lastSessionQuality * 100).round()}%  ·  Momentum ${(summary.momentum * 100).round()}%',
            style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            'Adaptability ${(summary.adaptability * 100).round()}%',
            style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
          ),
          if (summary.hasPrediction) ...[
            const SizedBox(height: 12),
            Text(
              'Prediction: ${summary.predictionOutcome} · ${(predictionProbability * 100).round()}%',
              style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 4),
            Text(
              predictionExplanation,
              style: const TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
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
        summary.predictionExplanation ?? 'Prediction details are unavailable right now.';
    final String forecast = summary.hasPrediction
        ? '${summary.predictionTitle}: ${summary.predictionOutcome} · ${(predictionProbability * 100).round()}%'
        : 'No explicit model prediction yet. Using live trajectory signals.';
    final String guidance = summary.hasPrediction ? predictionExplanation : summary.alert;

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
          Text(guidance, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricChip(label: 'ENERGY', value: '${(summary.energy * 100).round()}%'),
              _MetricChip(label: 'MOMENTUM', value: '${(summary.momentum * 100).round()}%'),
              _MetricChip(label: 'ADAPTABILITY', value: '${(summary.adaptability * 100).round()}%'),
              _MetricChip(label: 'PRESSURE', value: '${summary.pressureIndex}'),
              _MetricChip(label: 'DIVERGENCE', value: '${summary.behaviorDivergence}%'),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Recommended next move: complete one high-confidence task to reduce pressure and improve trajectory stability.',
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
            style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
