import 'package:fantastic_guacamole/state/providers/operator_state_provider.dart';
import 'package:fantastic_guacamole/state/providers/opportunity_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/predictive_risk_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AutonomousAction {
  const AutonomousAction({
    required this.title,
    required this.reason,
    required this.priority,
  });

  final String title;
  final String reason;
  final int priority;
}

final autonomousActionProvider = Provider<AutonomousAction>((ref) {
  final operator = ref.watch(operatorStateProvider);
  final risk = ref.watch(predictiveRiskProvider);
  final opportunities = ref.watch(opportunityEngineProvider);

  if (operator.status == OperatorStatus.recovering) {
    return AutonomousAction(
      title: 'Reduce Pressure',
      reason: risk.risks.first.mitigation,
      priority: 100,
    );
  }

  final bestOpportunity = opportunities.opportunities.first;

  return AutonomousAction(
    title: bestOpportunity.action,
    reason: bestOpportunity.summary,
    priority: 85,
  );
});
