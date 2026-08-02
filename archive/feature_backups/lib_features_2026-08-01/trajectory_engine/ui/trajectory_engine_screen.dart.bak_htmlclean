// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/providers/future_decision_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/future_timeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/identity_drift_provider.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_simulation_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';

class TrajectoryEngineScreen extends ConsumerWidget {
  const TrajectoryEngineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trajectory = ref.watch(trajectorySummaryProvider);
    final momentum = ref.watch(momentumEngineProvider);
    final simulations = ref.watch(trajectorySimulationProvider);
    final futureTimeline = ref.watch(futureTimelineProvider);
    final identityDrift = ref.watch(identityDriftProvider);
    final futureDecision = ref.watch(futureDecisionEngineProvider);
    final int momentumPercent = (trajectory.momentum * 100).round();

    return Scaffold(
      backgroundColor: const Color(0xFF070A12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070A12),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(appFlowProvider.notifier).toNexus();
          },
        ),
        title: const Text('FUTURE VECTOR'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _Panel(
            title: 'PROJECTED TIMELINE',
            child: Text(
              trajectory.predictionOutcome ?? 'Future path is stabilizing.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MetricGrid(
            momentumPercent: momentumPercent,
            pressureIndex: trajectory.pressureIndex,
            divergence: trajectory.behaviorDivergence,
            completedTasks: trajectory.completedTasks,
          ),
          const SizedBox(height: 12),

          _Panel(
            title: 'FUTURE HORIZON',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[
                Text(
                  'Trajectory remains active.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Momentum, adaptation, and execution indicate the projected path is continuing to develop. Continue reinforcing positive behavior signals.',
                  style: TextStyle(
                    color: Color(0xFFD8E2FF),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          _Panel(
            title: 'MOMENTUM INTELLIGENCE',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  momentum.trend,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  momentum.forecast,
                  style: const TextStyle(
                    color: Color(0xFFD8E2FF),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Momentum ${momentum.score}%  ·  Energy ${momentum.energyPercent}%  ·  Pressure ${momentum.pressurePercent}%',
                  style: const TextStyle(
                    color: Color(0xFF7F91C8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Recovery: ${momentum.recovery}',
                  style: const TextStyle(
                    color: Color(0xFFB8C7FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          _TrajectorySimulationCard(simulations: simulations),
          const SizedBox(height: 12),
          _FutureRoadmapCard(
            timeline: futureTimeline,
            drift: identityDrift,
            decision: futureDecision,
          ),
          const SizedBox(height: 12),
          _Panel(title: 'SUCCESS FORECAST', child: Text('% · ')),

          const SizedBox(height: 12),

          _Panel(
            title: 'COURSE CORRECTION',
            child: Text(
              trajectory.alert,
              style: const TextStyle(
                color: Color(0xFFB8C7FF),
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _TrajectorySimulationCard extends StatelessWidget {
  const _TrajectorySimulationCard({required this.simulations});

  final List<TrajectorySimulationResult> simulations;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'SIMULATION',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: simulations.map((simulation) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: simulation == simulations.last ? 0 : 12,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10182A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2A3D68)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    simulation.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    simulation.summary,
                    style: const TextStyle(
                      color: Color(0xFFD8E2FF),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _ProjectionPill(
                        label: 'Momentum',
                        value: '${simulation.projectedMomentum}%',
                      ),
                      _ProjectionPill(
                        label: 'Pressure',
                        value: '${simulation.projectedPressure}%',
                      ),
                      _ProjectionPill(
                        label: 'Recovery',
                        value: simulation.projectedRecovery,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    simulation.projectedOutcome,
                    style: const TextStyle(
                      color: Color(0xFFB8C7FF),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ProjectionPill extends StatelessWidget {
  const _ProjectionPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1322),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF24345B)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Color(0xFF7F91C8),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FutureRoadmapCard extends StatelessWidget {
  const _FutureRoadmapCard({
    required this.timeline,
    required this.drift,
    required this.decision,
  });

  final FutureTimelineState timeline;
  final IdentityDriftState drift;
  final FutureDecision decision;

  Color get _driftColor {
    switch (drift.alignment) {
      case IdentityAlignment.aligned:
        return const Color(0xFF00E5FF);
      case IdentityAlignment.drifting:
        return const Color(0xFFFFC857);
      case IdentityAlignment.diverging:
        return const Color(0xFFFF5D73);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'FUTURE ROADMAP',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Decision: ${decision.recommendedChoice}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Alignment ${drift.score}% - ${drift.summary}',
            style: TextStyle(
              color: _driftColor,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...timeline.checkpoints.map((FutureTimelineCheckpoint checkpoint) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10182A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF24345B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    checkpoint.label,
                    style: const TextStyle(
                      color: Color(0xFF6EE7F9),
                      fontSize: 10,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    checkpoint.prediction,
                    style: const TextStyle(
                      color: Color(0xFFD8E2FF),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          Text(
            'Correction: ${drift.correction}',
            style: const TextStyle(
              color: Color(0xFFB8C7FF),
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.momentumPercent,
    required this.pressureIndex,
    required this.divergence,
    required this.completedTasks,
  });

  final int momentumPercent;
  final int pressureIndex;
  final int divergence;
  final int completedTasks;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: <Widget>[
        _MetricCard(label: 'VELOCITY', value: '$momentumPercent%'),
        _MetricCard(label: 'PRESSURE', value: '$pressureIndex'),
        _MetricCard(label: 'EVOLUTION', value: '$divergence%'),
        _MetricCard(label: 'REALIZED', value: '$completedTasks'),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF10182A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF23345A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF7F91C8),
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF0D1322), Color(0xFF15233F)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF24345B)),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x2200FFFF), blurRadius: 20),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF6EE7F9),
              fontSize: 12,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
