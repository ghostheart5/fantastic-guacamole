import 'package:fantastic_guacamole/state/providers/adaptive_replanning_provider.dart';
import 'package:fantastic_guacamole/state/providers/autonomous_action_provider.dart';
import 'package:fantastic_guacamole/state/providers/completion_events_provider.dart';
import 'package:fantastic_guacamole/state/providers/goal_success_probability_provider.dart';
import 'package:fantastic_guacamole/state/providers/memory_intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/operator_state_provider.dart';
import 'package:fantastic_guacamole/state/providers/opportunity_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/predictive_risk_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_drift_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IntelligenceFusionState {
  const IntelligenceFusionState({
    required this.operatingMode,
    required this.primaryThreat,
    required this.primaryOpportunity,
    required this.nextAction,
    required this.rationale,
    required this.successForecast,
    required this.driftStatus,
    required this.memoryLesson,
    required this.replanMove,
  });

  final String operatingMode;
  final String primaryThreat;
  final String primaryOpportunity;
  final String nextAction;
  final String rationale;
  final String successForecast;
  final String driftStatus;
  final String memoryLesson;
  final String replanMove;
}

final intelligenceFusionProvider = Provider<IntelligenceFusionState>((ref) {
  final momentum = ref.watch(momentumEngineProvider);
  final operator = ref.watch(operatorStateProvider);
  final action = ref.watch(autonomousActionProvider);
  final risk = ref.watch(predictiveRiskProvider);
  final opportunity = ref.watch(opportunityEngineProvider);
  final success = ref.watch(goalSuccessProbabilityProvider);
  final drift = ref.watch(trajectoryDriftProvider);
  final memory = ref.watch(memoryIntelligenceProvider);
  final replans = ref.watch(adaptiveReplanningProvider);
  final completionEvents = ref.watch(completionEventsProvider);

  final String primaryThreat = risk.risks.isEmpty
      ? 'No major threat detected.'
      : '${risk.risks.first.title}: ${risk.risks.first.summary}';

  final String primaryOpportunity = opportunity.opportunities.isEmpty
      ? 'No major opportunity detected.'
      : '${opportunity.opportunities.first.title}: ${opportunity.opportunities.first.summary}';

  final String replanMove = replans.isEmpty
      ? 'No replan required.'
      : '${replans.first.title}: ${replans.first.immediateAction}';

  final String operatingMode = switch (operator.status) {
    OperatorStatus.recovering => 'Recovery Mode',
    OperatorStatus.stabilizing => 'Stabilization Mode',
    OperatorStatus.accelerating => 'Acceleration Mode',
    OperatorStatus.executing => 'Execution Mode',
  };

  final String rationale =
      'Momentum ${momentum.score}% ${momentum.trend}. '
      'Success forecast ${success.probability}%. '
      'Drift score ${drift.score}%. '
      'Completion signal ${completionEvents.length} recent '
      '${completionEvents.isEmpty ? 'none' : completionEvents.first.eventType.name}. '
      '${operator.rationale}';

  return IntelligenceFusionState(
    operatingMode: operatingMode,
    primaryThreat: primaryThreat,
    primaryOpportunity: primaryOpportunity,
    nextAction: action.title,
    rationale: rationale,
    successForecast: '${success.probability}% - ${success.summary}',
    driftStatus: '${drift.score}% - ${drift.summary}',
    memoryLesson: memory.lesson,
    replanMove: replanMove,
  );
});
