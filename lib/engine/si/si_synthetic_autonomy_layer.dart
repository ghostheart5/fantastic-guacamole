// lib/engine/si/si_synthetic_autonomy_layer.dart
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIAutonomyProfile {
  const SIAutonomyProfile({
    required this.autonomyRisk,
    required this.permissionNeeded,
    required this.allowedAction,
    required this.memory,
  });
  final double autonomyRisk;
  final bool permissionNeeded;
  final String allowedAction;
  final SIMemoryStore memory;
}

class SISyntheticAutonomyLayer {
  const SISyntheticAutonomyLayer();

  SIAutonomyProfile evaluate({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    SIDecision? decision,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final action = decision?.action ?? _action(intent.primary.label);
    final destructive = RegExp(r'(delete|clear|reset|remove)').hasMatch(action);
    final risk = siClamp01(
      (destructive ? .45 : 0) +
          (intent.confidence < .55 ? .2 : 0) +
          (instinct.safetyFirst ? .25 : 0) +
          (context.userState.cognitiveLoad >= .72 ? .15 : 0),
    );
    final allowed = risk >= .7 ? 'respond_conversationally' : action;
    final next = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content:
                'synthetic_autonomy|risk=${risk.toStringAsFixed(2)}|allowed=$allowed',
            timestamp: t,
            relevance: 1 - risk,
            confidence: .74,
            emotionalWeight: risk,
            reinforcement: risk < .4 ? 1 : 0,
          ),
        )
        .dedupe()
        .decay(t);
    return SIAutonomyProfile(
      autonomyRisk: risk,
      permissionNeeded: destructive || risk >= .55,
      allowedAction: allowed,
      memory: next,
    );
  }

  String _action(String i) => switch (i) {
    'start_focus' => 'launch_focus_session',
    'get_task' => 'present_task_recommendation',
    'reflect' => 'open_reflection_flow',
    'insight_request' => 'show_insight_summary',
    _ => 'respond_conversationally',
  };
}
