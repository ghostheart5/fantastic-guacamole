import 'package:fantastic_guacamole/core/services/si_engine_service.dart';
import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
import 'package:fantastic_guacamole/features/coach/models/coach_state.dart';

// Coach Orchestrator — merges CoachEngine + ResponseBuilder through SIEngineService.
// No feature accesses si_core directly; all SI decisions flow through here.

class CoachOrchestrator {
  const CoachOrchestrator(this._siEngine);

  final SIEngineService _siEngine;

  Future<CoachState> recommend({
    required String focusTask,
    required bool canStartFocus,
  }) async {
    final SiDecisionEntity decision = await _siEngine.think(
      'coach recommendation for task: $focusTask',
    );

    final String recommendation;
    if (focusTask.trim().isEmpty) {
      recommendation = 'Let us create your first task.';
    } else if (decision.shouldSimplify) {
      recommendation =
          'Start with just ${decision.recommendedFocusMinutes} min on $focusTask';
    } else {
      recommendation = 'Start Deep Work on $focusTask';
    }

    return CoachState(
      recommendation: recommendation,
      reason: decision.action.isNotEmpty
          ? decision.action
          : 'SI recommends this task.',
      canStartFocus: canStartFocus && !decision.shouldTakeBreak,
    );
  }

  String streakMessage({required bool atRisk}) => atRisk
      ? 'You have not done a session today. A quick 5-minute session keeps your streak alive.'
      : 'Momentum is stable. Keep showing up.';
}
