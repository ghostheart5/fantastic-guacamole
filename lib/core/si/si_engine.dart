import 'task_suggester.dart';

enum EnergyLevel { low, medium, high }

class SiTask {
  const SiTask({required this.title, required this.priority, this.hasDeadline = false});

  final String title;
  final int priority;
  final bool hasDeadline;
}

class UserSignalState {
  const UserSignalState({
    required this.energyLevel,
    required this.tasks,
    required this.workload,
    required this.deadlinePressure,
  });

  final EnergyLevel energyLevel;
  final List<SiTask> tasks;
  final double workload;
  final double deadlinePressure;
}

class SiDecision {
  const SiDecision({
    required this.primaryDecision,
    required this.secondaryAction,
    required this.optionalAction,
    required this.systemNote,
    required this.focusTasks,
    required this.energy,
    required this.workload,
  });

  final String primaryDecision;
  final String secondaryAction;
  final String optionalAction;
  final String systemNote;
  final List<SiTask> focusTasks;
  final double energy;
  final double workload;
}

class SiEngine {
  const SiEngine({TaskSuggester? suggester}) : _suggester = suggester ?? const TaskSuggester();

  final TaskSuggester _suggester;

  SiDecision generateDecision(
    UserSignalState state, {
    DateTime? now,
    double outputLoadModifier = 1,
    List<String> recentBehavior = const <String>[],
    double Function(String taskTitle)? adaptiveScoreOf,
  }) {
    final DateTime stamp = now ?? DateTime.now();
    final double energy = _energyScore(state.energyLevel);
    final double load = _normalizedLoad(state);
    final List<SiTask> rankedReal = List<SiTask>.from(state.tasks)
      ..sort((SiTask a, SiTask b) {
        final double adaptiveA = adaptiveScoreOf?.call(a.title) ?? 0;
        final double adaptiveB = adaptiveScoreOf?.call(b.title) ?? 0;

        final int deadlineA = a.hasDeadline ? 1 : 0;
        final int deadlineB = b.hasDeadline ? 1 : 0;
        final int deadlineCompare = deadlineB.compareTo(deadlineA);
        if (deadlineCompare != 0) {
          return deadlineCompare;
        }

        final double scoreA = (a.priority / 10) + adaptiveA;
        final double scoreB = (b.priority / 10) + adaptiveB;
        return scoreB.compareTo(scoreA);
      });

    final TaskSuggestionResult suggestions = _suggester.suggest(
      state: state,
      now: stamp,
      outputLoadModifier: outputLoadModifier,
      recentBehavior: recentBehavior,
    );

    final List<SiTask> prioritized = <SiTask>[...rankedReal];
    if (prioritized.length < 3) {
      for (final SiTask suggested in suggestions.recommended.followedBy(suggestions.fallback)) {
        final bool alreadyPresent = prioritized.any((SiTask task) => task.title == suggested.title);
        if (!alreadyPresent) {
          prioritized.add(suggested);
        }
        if (prioritized.length >= 3) {
          break;
        }
      }
    }

    final List<SiTask> focus = prioritized.take(3).toList();

    if (focus.isEmpty) {
      return SiDecision(
        primaryDecision: 'No active tasks. Enter capture mode.',
        secondaryAction: 'Generate a starter mission and schedule one focus block.',
        optionalAction: 'Run SI reflection and capture loose inputs.',
        systemNote: suggestions.systemHint,
        focusTasks: focus,
        energy: energy,
        workload: load,
      );
    }

    if (load >= 0.75) {
      return SiDecision(
        primaryDecision: 'Execute ${focus.first.title}',
        secondaryAction: 'Defer remaining tasks outside top 3 focus window.',
        optionalAction: 'Restructure timeline to reduce overlap and cognitive switching.',
        systemNote:
            'Overload detected. Limiting active focus threads to three. ${suggestions.systemHint}',
        focusTasks: focus,
        energy: energy,
        workload: load,
      );
    }

    if (energy <= 0.35) {
      return SiDecision(
        primaryDecision: 'Start with a low-friction win: ${focus.first.title}',
        secondaryAction: 'Short recovery cycle before deep work block.',
        optionalAction: 'Queue one admin task and one recovery break.',
        systemNote:
            'Low energy profile detected. Optimizing for momentum. ${suggestions.systemHint}',
        focusTasks: focus,
        energy: energy,
        workload: load,
      );
    }

    if (state.deadlinePressure >= 0.7) {
      return SiDecision(
        primaryDecision: 'Prioritize deadline-critical task: ${focus.first.title}',
        secondaryAction: 'Reserve a protected completion block in Temporal Ops.',
        optionalAction: 'Move low-impact work to post-deadline buffer.',
        systemNote:
            'Deadline pressure elevated. Advancing completion protocol. ${suggestions.systemHint}',
        focusTasks: focus,
        energy: energy,
        workload: load,
      );
    }

    return SiDecision(
      primaryDecision: 'Continue primary trajectory: ${focus.first.title}',
      secondaryAction:
          'Promote ${focus.length > 1 ? focus[1].title : 'next item'} as backup action.',
      optionalAction: focus.length > 2
          ? 'Hold ${focus[2].title} as optional action.'
          : 'Run a short reflection and queue tomorrow priorities.',
      systemNote: 'System balanced. Maintaining strategic cadence. ${suggestions.systemHint}',
      focusTasks: focus,
      energy: energy,
      workload: load,
    );
  }

  double _energyScore(EnergyLevel level) {
    switch (level) {
      case EnergyLevel.low:
        return 0.25;
      case EnergyLevel.medium:
        return 0.58;
      case EnergyLevel.high:
        return 0.88;
    }
  }

  double _normalizedLoad(UserSignalState state) {
    final double taskFactor = (state.tasks.length / 8).clamp(0.0, 1.0);
    return ((state.workload * 0.6) + (taskFactor * 0.25) + (state.deadlinePressure * 0.15)).clamp(
      0.0,
      1.0,
    );
  }
}
