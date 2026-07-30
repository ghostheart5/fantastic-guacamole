import 'package:fantastic_guacamole/state/providers/autonomous_daily_planner_provider.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum FocusIntensity { light, standard, deep, recovery }

class AutonomousFocusBlock {
  const AutonomousFocusBlock({
    required this.title,
    required this.reason,
    required this.intensity,
    required this.durationMinutes,
  });

  final String title;
  final String reason;
  final FocusIntensity intensity;
  final int durationMinutes;
}

final autonomousFocusSchedulerProvider = Provider<AutonomousFocusBlock>((ref) {
  final daily = ref.watch(autonomousDailyPlannerProvider);
  final momentum = ref.watch(momentumEngineProvider);

  if (momentum.pressurePercent >= 75) {
    return const AutonomousFocusBlock(
      title: 'Recovery Focus Block',
      reason: 'Pressure is high. Reduce load before deep execution.',
      intensity: FocusIntensity.recovery,
      durationMinutes: 15,
    );
  }

  if (momentum.energyPercent < 45) {
    return const AutonomousFocusBlock(
      title: 'Light Momentum Block',
      reason: 'Energy is low. Build rhythm through a small completion.',
      intensity: FocusIntensity.light,
      durationMinutes: 20,
    );
  }

  if (momentum.score >= 70 && momentum.energyPercent >= 65) {
    return AutonomousFocusBlock(
      title: daily.focus,
      reason: 'Momentum and energy support deep high-leverage work.',
      intensity: FocusIntensity.deep,
      durationMinutes: 50,
    );
  }

  return AutonomousFocusBlock(
    title: daily.focus,
    reason:
        'Standard execution block recommended from today'
        's plan.',
    intensity: FocusIntensity.standard,
    durationMinutes: 30,
  );
});
