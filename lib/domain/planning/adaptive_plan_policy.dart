/// CHRONOSPARK-CLASS: SHIPPING | Feature: Smart Planner
class AdaptivePlanPolicy {
  const AdaptivePlanPolicy({
    this.priorityWeight = 1,
    this.deadlineWeight = 1,
    this.energyWeight = 1,
    this.goalBonus = 0,
    this.quickWinBonus = 0,
    this.adaptDurationToEnergy = true,
    this.fixedBreakMinutes,
  });

  final double priorityWeight;
  final double deadlineWeight;
  final double energyWeight;
  final double goalBonus;
  final double quickWinBonus;
  final bool adaptDurationToEnergy;
  final int? fixedBreakMinutes;
}
