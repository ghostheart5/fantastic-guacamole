enum ChronoTaskStatus { pending, active, done, skipped }

enum ChronoEventType { task, meeting, breakTime }

enum ChronoLogStatus { info, success, warning, error }

class ChronoUserState {
  const ChronoUserState({
    required this.energy,
    required this.cognitiveLoad,
    required this.focusLevel,
    required this.mood,
    required this.timeAvailable,
  });

  final double energy;
  final double cognitiveLoad;
  final double focusLevel;
  final double mood;
  final Duration timeAvailable;
}

class ChronoTask {
  const ChronoTask({
    required this.id,
    required this.title,
    required this.priority,
    required this.difficulty,
    required this.duration,
    required this.status,
  });

  final String id;
  final String title;
  final int priority;
  final int difficulty;
  final Duration duration;
  final ChronoTaskStatus status;
}

class ChronoMission {
  const ChronoMission({
    required this.id,
    required this.title,
    required this.tasks,
    required this.deadline,
    required this.importance,
  });

  final String id;
  final String title;
  final List<ChronoTask> tasks;
  final DateTime? deadline;
  final int importance;
}

class ChronoRoutine {
  const ChronoRoutine({required this.id, required this.sequence, required this.scheduledTime});

  final String id;
  final List<ChronoTask> sequence;
  final DateTime scheduledTime;
}

class ChronoGoal {
  const ChronoGoal({required this.id, required this.objective, required this.milestones});

  final String id;
  final String objective;
  final List<String> milestones;
}

class ChronoDecision {
  const ChronoDecision({
    required this.primaryAction,
    required this.secondaryAction,
    this.optionalAction,
    required this.systemNote,
  });

  final String primaryAction;
  final String secondaryAction;
  final String? optionalAction;
  final String systemNote;
}

class ChronoEvent {
  const ChronoEvent({
    required this.startTime,
    required this.endTime,
    required this.type,
    required this.importance,
  });

  final DateTime startTime;
  final DateTime endTime;
  final ChronoEventType type;
  final int importance;
}

class ChronoLog {
  const ChronoLog({
    required this.timestamp,
    required this.type,
    required this.content,
    required this.status,
  });

  final DateTime timestamp;
  final String type;
  final String content;
  final ChronoLogStatus status;
}

class ChronoUseCaseCatalog {
  const ChronoUseCaseCatalog();

  static const List<String> nexus = <String>[
    'View current decision',
    'View 3 Sparks',
    'Check energy/load',
    'Jump to modules',
    'Follow recommendation',
    'Ignore recommendation',
  ];

  static const List<String> creator = <String>[
    'Create task',
    'Create mission',
    'Build routine',
    'Create goal',
    'Edit structures',
    'Accept SI suggestions',
  ];

  static const List<String> temporalOps = <String>[
    'View day timeline',
    'View weekly flow',
    'View monthly map',
    'Move tasks',
    'Override schedule',
    'Accept optimization',
  ];

  static const List<String> siConsole = <String>[
    'Input thoughts',
    'Input commands',
    'View insights',
    'View mood trends',
    'Adjust system behavior',
    'Ask system for help',
  ];

  static const List<String> chronoLogs = <String>[
    'View past tasks',
    'View history',
    'Search logs',
    'Review patterns',
  ];

  static const List<String> settings = <String>[
    'Change theme',
    'Configure notifications',
    'Adjust SI behavior',
    'Manage data',
  ];
}
