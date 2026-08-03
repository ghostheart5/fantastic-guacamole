import 'package:fantastic_guacamole/state/providers/autonomous_action_provider.dart';
import 'package:fantastic_guacamole/state/providers/autonomous_daily_planner_provider.dart';
import 'package:fantastic_guacamole/state/providers/autonomous_weekly_planner_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('autonomousDailyPlannerProvider', () {
    test('focus and directive priorities are derived from action and weekly plan', () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          autonomousActionProvider.overrideWithValue(
            const AutonomousAction(
              title: 'Ship release notes',
              reason: 'Highest impact now.',
              priority: 95,
            ),
          ),
          autonomousWeeklyPlannerProvider.overrideWithValue(
            const AutonomousWeeklyPlan(
              theme: 'Stability',
              primaryDirective: 'Protect reliability',
              directives: <WeeklyDirective>[],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final AutonomousDailyPlan plan = container.read(autonomousDailyPlannerProvider);

      expect(plan.focus, 'Ship release notes');
      expect(plan.directives.length, 3);
      expect(plan.directives.first.priority, 100);
      expect(plan.directives[1].priority, 92);
      expect(plan.directives[1].reason, contains('Stability'));
      expect(plan.directives[2].reason, contains('Protect reliability'));
    });

    test('secondary directive priority scales down when action priority is below 90', () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          autonomousActionProvider.overrideWithValue(
            const AutonomousAction(
              title: 'Clear inbox',
              reason: 'Reduce clutter.',
              priority: 80,
            ),
          ),
          autonomousWeeklyPlannerProvider.overrideWithValue(
            const AutonomousWeeklyPlan(
              theme: 'Execution',
              primaryDirective: 'Finish one core task',
              directives: <WeeklyDirective>[],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final AutonomousDailyPlan plan = container.read(autonomousDailyPlannerProvider);
      expect(plan.directives[1].priority, 84);
    });
  });
}
