import 'si_engine.dart';

class TaskSuggestionResult {
  const TaskSuggestionResult({
    required this.recommended,
    required this.fallback,
    required this.systemHint,
  });

  final List<SiTask> recommended;
  final List<SiTask> fallback;
  final String systemHint;
}

class TaskSuggester {
  const TaskSuggester();

  TaskSuggestionResult suggest({
    required UserSignalState state,
    required DateTime now,
    required double outputLoadModifier,
    List<String> recentBehavior = const <String>[],
  }) {
    final bool lowEnergy = state.energyLevel == EnergyLevel.low;
    final bool highEnergy = state.energyLevel == EnergyLevel.high;
    final bool overload = state.workload >= 0.78 || state.tasks.length >= 7;
    final bool noTasks = state.tasks.isEmpty;

    if (noTasks) {
      final List<SiTask> starters = <SiTask>[
        const SiTask(title: 'Create top-3 mission list', priority: 7, hasDeadline: false),
        const SiTask(title: 'Define one 45m focus block', priority: 6, hasDeadline: false),
        const SiTask(title: 'Capture open loops from memory', priority: 6, hasDeadline: false),
      ];
      return TaskSuggestionResult(
        recommended: starters,
        fallback: starters,
        systemHint: 'No tasks detected. Starter tasks generated to bootstrap momentum.',
      );
    }

    final List<SiTask> recommended = <SiTask>[];

    if (overload) {
      recommended.add(
        const SiTask(
          title: 'Reduce active tasks to top 3 and defer the rest',
          priority: 10,
          hasDeadline: true,
        ),
      );
      recommended.add(
        const SiTask(title: 'Restructure schedule around one critical outcome', priority: 9),
      );
    }

    if (lowEnergy) {
      recommended.addAll(<SiTask>[
        const SiTask(title: 'Execute one low-friction admin task', priority: 6),
        const SiTask(title: 'Run 10-minute planning reset', priority: 5),
      ]);
    }

    if (highEnergy) {
      recommended.addAll(<SiTask>[
        const SiTask(
          title: 'Start a deep work sprint on highest-priority mission',
          priority: 9,
          hasDeadline: true,
        ),
        const SiTask(title: 'Finish a complex task before context switch', priority: 8),
      ]);
    }

    final bool userOverwhelmed = recentBehavior.any(
      (String entry) => entry.toLowerCase().contains('overwhelmed'),
    );
    final bool reduceOutput = outputLoadModifier < 0.9 || userOverwhelmed;
    if (reduceOutput) {
      recommended.insert(
        0,
        const SiTask(title: 'Minimize output load: single-task execution mode', priority: 10),
      );
    }

    final List<SiTask> fallback = <SiTask>[
      const SiTask(title: 'Clarify next action for current mission', priority: 6),
      const SiTask(title: 'Review upcoming deadlines for today', priority: 6, hasDeadline: true),
      const SiTask(title: 'Update ChronoLogs with current state', priority: 5),
    ];

    final String hint = switch ((lowEnergy, highEnergy, overload)) {
      (true, _, true) => 'Overload + low energy detected. Focus on reducing cognitive pressure.',
      (true, _, false) => 'Low energy detected. Biasing toward lightweight execution.',
      (_, true, _) => 'High energy detected. Biasing toward deep, high-impact work.',
      (_, _, true) => 'Overload detected. Biasing toward restructuring and triage.',
      _ =>
        now.hour >= 20
            ? 'Late-day profile detected. Prioritizing closure and planning.'
            : 'Balanced profile detected. Continue structured execution.',
    };

    return TaskSuggestionResult(
      recommended: recommended.take(4).toList(),
      fallback: fallback,
      systemHint: hint,
    );
  }
}
