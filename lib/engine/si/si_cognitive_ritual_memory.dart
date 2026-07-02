class RitualMemory {
  const RitualMemory({
    required this.morningCheckIns,
    required this.nightlyReflections,
    required this.weeklyPlanning,
    required this.creativeSessions,
    required this.emotionalResets,
    required this.stability,
  });

  final int morningCheckIns;
  final int nightlyReflections;
  final int weeklyPlanning;
  final int creativeSessions;
  final int emotionalResets;
  final double stability;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'morning_check_ins': morningCheckIns,
      'nightly_reflections': nightlyReflections,
      'weekly_planning': weeklyPlanning,
      'creative_sessions': creativeSessions,
      'emotional_resets': emotionalResets,
      'stability': stability,
    };
  }
}

class CognitiveRitualMemory {
  const CognitiveRitualMemory();

  RitualMemory track({required List<String> history}) {
    int count(String needle) =>
        history.where((String h) => h.toLowerCase().contains(needle)).length;
    final int morning = count('morning');
    final int nightly = count('night');
    final int weekly = count('weekly');
    final int creative = count('creative');
    final int reset = count('reset');
    final double stability =
        ((morning + nightly + weekly + creative + reset) / 25).clamp(0.0, 1.0);
    return RitualMemory(
      morningCheckIns: morning,
      nightlyReflections: nightly,
      weeklyPlanning: weekly,
      creativeSessions: creative,
      emotionalResets: reset,
      stability: stability,
    );
  }
}
