import 'package:fantastic_guacamole/state/providers/autonomous_weekly_planner_provider.dart';
import 'package:fantastic_guacamole/state/providers/autonomous_action_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DailyDirective {
  const DailyDirective({
    required this.title,
    required this.reason,
    required this.priority,
  });

  final String title;
  final String reason;
  final int priority;
}

class AutonomousDailyPlan {
  const AutonomousDailyPlan({required this.focus, required this.directives});

  final String focus;
  final List<DailyDirective> directives;
}

final autonomousDailyPlannerProvider = Provider<AutonomousDailyPlan>((ref) {
  final weekly = ref.watch(autonomousWeeklyPlannerProvider);
  final action = ref.watch(autonomousActionProvider);

  return AutonomousDailyPlan(
    focus: action.title,
    directives: <DailyDirective>[
      DailyDirective(title: action.title, reason: action.reason, priority: 100),
      DailyDirective(
        title: 'Protect one uninterrupted focus block',
        reason:
            'Daily stability should reinforce weekly theme ${weekly.theme} and reduce execution fragmentation.',
        priority: action.priority >= 90 ? 92 : 84,
      ),
      DailyDirective(
        title: 'Audit progress against primary directive',
        reason:
            'The active weekly directive is ${weekly.primaryDirective}, so daily completion should be measured against it.',
        priority: 70,
      ),
    ],
  );
});
