import 'package:fantastic_guacamole/state/providers/daily_command_briefing_provider.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExplainableSIReason {
  const ExplainableSIReason({
    required this.label,
    required this.detail,
    required this.severity,
  });

  final String label;
  final String detail;
  final ExplainableSISeverity severity;
}

enum ExplainableSISeverity { positive, neutral, warning }

class ExplainableSIState {
  const ExplainableSIState({
    required this.primaryReason,
    required this.reasons,
    required this.recommendation,
  });

  final String primaryReason;
  final List<ExplainableSIReason> reasons;
  final String recommendation;
}

final explainableSIProvider = Provider<ExplainableSIState>((ref) {
  final momentum = ref.watch(momentumEngineProvider);
  final briefing = ref.watch(dailyCommandBriefingProvider);

  final List<ExplainableSIReason> reasons = <ExplainableSIReason>[
    ExplainableSIReason(
      label: 'Momentum',
      detail: '${momentum.score}% ${momentum.trend}',
      severity: momentum.score >= 70
          ? ExplainableSISeverity.positive
          : momentum.score >= 45
          ? ExplainableSISeverity.neutral
          : ExplainableSISeverity.warning,
    ),
    ExplainableSIReason(
      label: 'Energy',
      detail: '${momentum.energyPercent}% available',
      severity: momentum.energyPercent >= 65
          ? ExplainableSISeverity.positive
          : momentum.energyPercent >= 40
          ? ExplainableSISeverity.neutral
          : ExplainableSISeverity.warning,
    ),
    ExplainableSIReason(
      label: 'Pressure',
      detail: '${momentum.pressurePercent}% load',
      severity: momentum.pressurePercent >= 70
          ? ExplainableSISeverity.warning
          : momentum.pressurePercent >= 45
          ? ExplainableSISeverity.neutral
          : ExplainableSISeverity.positive,
    ),
    ExplainableSIReason(
      label: 'Recovery',
      detail: momentum.recovery,
      severity: momentum.recovery == 'Recovery Needed'
          ? ExplainableSISeverity.warning
          : momentum.recovery == 'Watch Load'
          ? ExplainableSISeverity.neutral
          : ExplainableSISeverity.positive,
    ),
  ];

  final String primaryReason = momentum.score >= 70
      ? 'High momentum and usable energy support a high-impact move.'
      : momentum.score >= 45
      ? 'Momentum is stable, so one clear action is the best next step.'
      : 'Momentum is low, so recovery-first execution is recommended.';

  return ExplainableSIState(
    primaryReason: primaryReason,
    reasons: reasons,
    recommendation: briefing.recommendedAction,
  );
});
