/// CHRONOSPARK-CLASS: SHIPPING | Feature: Task ranking
class TaskRankingPolicy {
  const TaskRankingPolicy({
    this.priorityWeight = 1,
    this.deadlineWeight = 1,
    this.energyWeight = 1,
    this.goalBonus = 0,
    this.quickWinBonus = 0,
  });

  final double priorityWeight;
  final double deadlineWeight;
  final double energyWeight;
  final double goalBonus;
  final double quickWinBonus;
}
