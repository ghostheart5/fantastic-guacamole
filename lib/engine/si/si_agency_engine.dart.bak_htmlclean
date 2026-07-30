// lib/engine/si/si_agency_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class AgencyProfile {
  const AgencyProfile({
    required this.userControl,
    required this.autonomyRisk,
    required this.permissionNeeded,
    required this.allowedAction,
    required this.guidance,
  });

  final double userControl;
  final double autonomyRisk;
  final bool permissionNeeded;
  final String allowedAction;
  final String guidance;
}

class SIAgencyEngine {
  const SIAgencyEngine();

  AgencyProfile evaluate({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    SIDecision? decision,
  }) {
    final String action = decision?.action ?? _action(intent.primary.label);
    final bool destructive = _destructive(action);
    final bool uncertain = intent.confidence < 0.55 || instinct.reduceConfusion;
    final bool overloaded =
        instinct.avoidOverwhelm || context.userState.cognitiveLoad >= 0.72;

    final double risk = siClamp01(
      (destructive ? 0.45 : 0) +
          (uncertain ? 0.25 : 0) +
          (overloaded ? 0.2 : 0) +
          (instinct.safetyFirst ? 0.25 : 0),
    );

    return AgencyProfile(
      userControl: siClamp01(1 - risk),
      autonomyRisk: risk,
      permissionNeeded: destructive || risk >= 0.55,
      allowedAction: risk >= 0.75 ? 'respond_conversationally' : action,
      guidance: risk >= 0.55
          ? 'Ask before acting and preserve user control.'
          : 'Proceed with guidance while keeping user choice explicit.',
    );
  }

  String _action(String intent) {
    switch (intent) {
      case 'start_focus':
        return 'launch_focus_session';
      case 'get_task':
        return 'present_task_recommendation';
      case 'reflect':
        return 'open_reflection_flow';
      case 'insight_request':
        return 'show_insight_summary';
      default:
        return 'respond_conversationally';
    }
  }

  bool _destructive(String action) {
    return action.contains('delete') ||
        action.contains('reset') ||
        action.contains('clear');
  }
}
