import 'package:fantastic_guacamole/state/providers/future_decision_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/life_os_provider.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
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
  final momentum = ref.watch(momentumEngineProvider);

  return AutonomousWeeklyPlan(
    theme: lifeOs.identityStage,
    primaryDirective: decision.recommendedChoice,
    directives: <WeeklyDirective>[
      WeeklyDirective(
        title: decision.recommendedChoice,
        reason:
            'Highest alignment with current direction signal and momentum trend ${momentum.trend.toLowerCase()}.',
      ),
      WeeklyDirective(
        title: momentum.pressurePercent >= 65
            ? 'Reduce execution pressure before scaling output'
            : 'Protect execution depth on the primary directive',
        reason:
            'Pressure is ${momentum.pressurePercent}% and energy is ${momentum.energyPercent}%, so weekly reliability depends on correct load calibration.',
      ),
      WeeklyDirective(
        title: 'Re-check trajectory against ${lifeOs.nextMilestone}',
        reason:
            'Direction remains valid only if weekly execution still supports the next checkpoint.',
      ),
    ],
  );
});
