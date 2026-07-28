import 'package:fantastic_guacamole/state/providers/daily_command_briefing_provider.dart';
import 'package:fantastic_guacamole/state/providers/goal_success_probability_provider.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/predictive_risk_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OperatorStatus { executing, stabilizing, recovering, accelerating }

class OperatorState {
  const OperatorState({
    required this.status,
    required this.title,
    required this.command,
    required this.rationale,
  });

  final OperatorStatus status;
  final String title;
  final String command;
  final String rationale;
}

final operatorStateProvider = Provider<OperatorState>((ref) {
  final momentum = ref.watch(momentumEngineProvider);
  final risk = ref.watch(predictiveRiskProvider);
  final briefing = ref.watch(dailyCommandBriefingProvider);
  final forecast = ref.watch(goalSuccessProbabilityProvider);

  if (momentum.pressurePercent >= 75) {
    return OperatorState(
      status: OperatorStatus.recovering,
      title: 'Recovery Mode',
      command: 'Reduce pressure immediately.',
      rationale: risk.risks.first.mitigation,
    );
  }

  if (forecast.probability >= 80 && momentum.score >= 70) {
    return OperatorState(
      status: OperatorStatus.accelerating,
      title: 'Acceleration Mode',
      command: briefing.coachAction,
      rationale: 'Momentum and predicted success are both strong.',
    );
  }

  if (momentum.score < 45) {
    return const OperatorState(
      status: OperatorStatus.stabilizing,
      title: 'Stabilization Mode',
      command: 'Complete one visible task before expanding scope.',
      rationale: 'Momentum recovery is the highest-leverage move.',
    );
  }

  return OperatorState(
    status: OperatorStatus.executing,
    title: 'Execution Mode',
    command: briefing.coachAction,
    rationale: briefing.focus,
  );
});
