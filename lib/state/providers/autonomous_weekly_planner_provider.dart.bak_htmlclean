import 'package:fantastic_guacamole/state/providers/future_decision_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/life_os_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WeeklyDirective {
  const WeeklyDirective({required this.title, required this.reason});

  final String title;
  final String reason;
}

class AutonomousWeeklyPlan {
  const AutonomousWeeklyPlan({
    required this.theme,
    required this.primaryDirective,
    required this.directives,
  });

  final String theme;
  final String primaryDirective;
  final List<WeeklyDirective> directives;
}

final autonomousWeeklyPlannerProvider = Provider<AutonomousWeeklyPlan>((ref) {
  final lifeOs = ref.watch(lifeOSProvider);
  final decision = ref.watch(futureDecisionEngineProvider);

  return AutonomousWeeklyPlan(
    theme: lifeOs.identityStage,
    primaryDirective: decision.recommendedChoice,
    directives: <WeeklyDirective>[
      WeeklyDirective(
        title: decision.recommendedChoice,
        reason: 'Highest alignment with current future-self trajectory.',
      ),
      const WeeklyDirective(
        title: 'Protect focus blocks',
        reason: 'Preserve identity alignment and execution consistency.',
      ),
      const WeeklyDirective(
        title: 'Review trajectory',
        reason: 'Ensure direction remains aligned with Life OS mission.',
      ),
    ],
  );
});
