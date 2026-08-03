class NexusDailyBriefing {
  const NexusDailyBriefing({
    required this.risk,
    required this.opening,
    required this.nextMove,
  });

  final String risk;
  final String opening;
  final String nextMove;

  static NexusDailyBriefing build({
    required bool profileReady,
    required double energy,
    required int completedToday,
  }) {
    if (!profileReady) {
      return const NexusDailyBriefing(
        risk:
            'Signal coverage is still warming. Add a few items to sharpen the view.',
        opening:
            'One focused action will turn the dashboard into a useful daily brief.',
        nextMove: 'Complete setup, then create one priority item.',
      );
    }

    if (completedToday == 0) {
      return const NexusDailyBriefing(
        risk: 'No completion has been logged yet. The day is still open.',
        opening: 'A small win now can create the strongest opening.',
        nextMove:
            'Start with one priority task or habit and finish it before expanding.',
      );
    }

    if (energy >= 0.65) {
      return const NexusDailyBriefing(
        risk:
            'Momentum is available, but overloading the day is the main risk.',
        opening: 'High energy is ready to convert into one decisive move.',
        nextMove: 'Take the highest-leverage task into the next focus block.',
      );
    }

    if (energy >= 0.4) {
      return const NexusDailyBriefing(
        risk: 'Focus is steady. The main risk is spreading effort too thin.',
        opening: 'A short focused block can lift the day quickly.',
        nextMove:
            'Pick one clear task and protect it before adding anything else.',
      );
    }

    return const NexusDailyBriefing(
      risk: 'Energy is lower than ideal. The risk is overcommitting too early.',
      opening: 'A small win now is the best way to restore grip.',
      nextMove: 'Choose the smallest meaningful win and protect it.',
    );
  }
}
