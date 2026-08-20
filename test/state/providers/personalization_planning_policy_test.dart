import 'package:fantastic_guacamole/state/models/personalization_models.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('priority strategies map to distinct deterministic weights', () {
    expect(
      adaptivePlanPolicyFor(
        const PersonalizationProfile(
          priorityStrategy: PriorityStrategy.deadlineFirst,
        ),
      ).deadlineWeight,
      greaterThan(1),
    );
    expect(
      adaptivePlanPolicyFor(
        const PersonalizationProfile(
          priorityStrategy: PriorityStrategy.energyFirst,
        ),
      ).energyWeight,
      greaterThan(1),
    );
    expect(
      adaptivePlanPolicyFor(
        const PersonalizationProfile(
          priorityStrategy: PriorityStrategy.goalFirst,
        ),
      ).goalBonus,
      greaterThan(0),
    );
    expect(
      adaptivePlanPolicyFor(
        const PersonalizationProfile(
          priorityStrategy: PriorityStrategy.quickWins,
        ),
      ).quickWinBonus,
      greaterThan(0),
    );
  });

  test('planning styles change duration, break, and energy behavior', () {
    final flexible = adaptivePlanPolicyFor(const PersonalizationProfile());
    final timeBlocked = adaptivePlanPolicyFor(
      const PersonalizationProfile(planningStyle: PlanningStyle.timeBlocked),
    );
    final energyMatched = adaptivePlanPolicyFor(
      const PersonalizationProfile(planningStyle: PlanningStyle.energyMatched),
    );
    final singleTask = adaptivePlanPolicyFor(
      const PersonalizationProfile(planningStyle: PlanningStyle.singleTask),
    );

    expect(flexible.adaptDurationToEnergy, isTrue);
    expect(timeBlocked.adaptDurationToEnergy, isFalse);
    expect(timeBlocked.fixedBreakMinutes, 10);
    expect(energyMatched.energyWeight, greaterThan(flexible.energyWeight));
    expect(singleTask.priorityWeight, greaterThan(flexible.priorityWeight));
    expect(singleTask.fixedBreakMinutes, 15);
  });
}
