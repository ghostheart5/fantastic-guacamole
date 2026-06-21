import 'si_engine.dart';

class TaskBehaviorScore {
  const TaskBehaviorScore({
    required this.taskTitle,
    required this.priorityScore,
    required this.completionRate,
    required this.skipRate,
    required this.completedCount,
    required this.skippedCount,
    required this.delayedCount,
    this.lastCompletedHour,
  });

  final String taskTitle;
  final double priorityScore;
  final double completionRate;
  final double skipRate;
  final int completedCount;
  final int skippedCount;
  final int delayedCount;
  final int? lastCompletedHour;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'taskTitle': taskTitle,
      'priorityScore': priorityScore,
      'completionRate': completionRate,
      'skipRate': skipRate,
      'completedCount': completedCount,
      'skippedCount': skippedCount,
      'delayedCount': delayedCount,
      'lastCompletedHour': lastCompletedHour,
    };
  }

  factory TaskBehaviorScore.fromJson(Map<String, dynamic> json) {
    return TaskBehaviorScore(
      taskTitle: (json['taskTitle'] as String?) ?? 'Untitled',
      priorityScore: (json['priorityScore'] as num?)?.toDouble() ?? 0,
      completionRate: (json['completionRate'] as num?)?.toDouble() ?? 0,
      skipRate: (json['skipRate'] as num?)?.toDouble() ?? 0,
      completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
      skippedCount: (json['skippedCount'] as num?)?.toInt() ?? 0,
      delayedCount: (json['delayedCount'] as num?)?.toInt() ?? 0,
      lastCompletedHour: (json['lastCompletedHour'] as num?)?.toInt(),
    );
  }
}

class AdaptiveLearningSystem {
  final Map<String, _TaskBehaviorMutable> _scores = <String, _TaskBehaviorMutable>{};
  final Map<int, int> _activeHourHistogram = <int, int>{};
  int _overwhelmedSignals = 0;
  int _consoleSignals = 0;

  double get outputLoadModifier {
    if (_consoleSignals == 0) {
      return 1;
    }
    final double ratio = _overwhelmedSignals / _consoleSignals;
    if (ratio >= 0.45) {
      return 0.7;
    }
    if (ratio >= 0.25) {
      return 0.85;
    }
    return 1;
  }

  int? get preferredHour {
    if (_activeHourHistogram.isEmpty) {
      return null;
    }
    return _activeHourHistogram.entries
        .reduce((MapEntry<int, int> a, MapEntry<int, int> b) => a.value >= b.value ? a : b)
        .key;
  }

  void registerCompletion(String taskTitle, {DateTime? now}) {
    final DateTime stamp = now ?? DateTime.now();
    final _TaskBehaviorMutable score = _scoreFor(taskTitle);
    score.completedCount += 1;
    score.lastCompletedHour = stamp.hour;
    _activeHourHistogram.update(stamp.hour, (int value) => value + 1, ifAbsent: () => 1);
    _recalculate(score);
  }

  void registerSkip(String taskTitle) {
    final _TaskBehaviorMutable score = _scoreFor(taskTitle);
    score.skippedCount += 1;
    _recalculate(score);
  }

  void registerDelay(String taskTitle) {
    final _TaskBehaviorMutable score = _scoreFor(taskTitle);
    score.delayedCount += 1;
    _recalculate(score);
  }

  void registerConsoleInput(String input) {
    final String lower = input.toLowerCase();
    _consoleSignals += 1;
    if (lower.contains('overwhelmed') || lower.contains('drained') || lower.contains('too much')) {
      _overwhelmedSignals += 1;
    }
  }

  List<SiTask> rankTasks(
    List<SiTask> tasks, {
    DateTime? now,
    double learningDepthFactor = 1.0,
    int historyWindowDays = 30,
  }) {
    final int? preferred = preferredHour;
    final int hour = (now ?? DateTime.now()).hour;
    final double depth = learningDepthFactor.clamp(0.4, 1.8);
    final double historyFactor = (historyWindowDays / 30).clamp(0.4, 2.0);
    final List<SiTask> ranked = List<SiTask>.from(tasks);
    ranked.sort((SiTask a, SiTask b) {
      final double scoreA = _weightedScore(
        a,
        hour: hour,
        preferredHour: preferred,
        learningDepthFactor: depth,
        historyFactor: historyFactor,
      );
      final double scoreB = _weightedScore(
        b,
        hour: hour,
        preferredHour: preferred,
        learningDepthFactor: depth,
        historyFactor: historyFactor,
      );
      return scoreB.compareTo(scoreA);
    });
    return ranked;
  }

  List<TaskBehaviorScore> exportScores() {
    return _scores.values.map((_TaskBehaviorMutable mutable) => mutable.freeze()).toList()..sort(
      (TaskBehaviorScore a, TaskBehaviorScore b) => b.priorityScore.compareTo(a.priorityScore),
    );
  }

  void restoreScores(List<TaskBehaviorScore> scores) {
    _scores
      ..clear()
      ..addEntries(
        scores.map(
          (TaskBehaviorScore score) => MapEntry<String, _TaskBehaviorMutable>(
            score.taskTitle,
            _TaskBehaviorMutable.fromFrozen(score),
          ),
        ),
      );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'scores': exportScores().map((TaskBehaviorScore s) => s.toJson()).toList(),
      'hourHistogram': _activeHourHistogram.map(
        (int key, int value) => MapEntry<String, int>(key.toString(), value),
      ),
      'overwhelmedSignals': _overwhelmedSignals,
      'consoleSignals': _consoleSignals,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawScores = json['scores'] as List<dynamic>? ?? const <dynamic>[];
    restoreScores(
      rawScores.map((dynamic e) => TaskBehaviorScore.fromJson(e as Map<String, dynamic>)).toList(),
    );

    _activeHourHistogram
      ..clear()
      ..addEntries(
        (json['hourHistogram'] as Map<String, dynamic>? ?? const <String, dynamic>{}).entries.map(
          (MapEntry<String, dynamic> e) =>
              MapEntry<int, int>(int.tryParse(e.key) ?? 0, (e.value as num?)?.toInt() ?? 0),
        ),
      );

    _overwhelmedSignals = (json['overwhelmedSignals'] as num?)?.toInt() ?? 0;
    _consoleSignals = (json['consoleSignals'] as num?)?.toInt() ?? 0;
  }

  double scoreForTask(String title) {
    return _scores[title]?.priorityScore ?? 0;
  }

  _TaskBehaviorMutable _scoreFor(String title) {
    return _scores.putIfAbsent(title, () => _TaskBehaviorMutable(taskTitle: title));
  }

  void _recalculate(_TaskBehaviorMutable score) {
    final int totalActions = score.completedCount + score.skippedCount + score.delayedCount;
    if (totalActions <= 0) {
      score.completionRate = 0;
      score.skipRate = 0;
      score.priorityScore = 0;
      return;
    }
    score.completionRate = score.completedCount / totalActions;
    score.skipRate = score.skippedCount / totalActions;

    final double delayPenalty = (score.delayedCount * 0.05).clamp(0, 0.35);
    score.priorityScore = ((score.completionRate * 1.1) - (score.skipRate * 0.9) - delayPenalty)
        .clamp(-1, 1);
  }

  double _weightedScore(
    SiTask task, {
    required int hour,
    required int? preferredHour,
    required double learningDepthFactor,
    required double historyFactor,
  }) {
    final double basePriority = (task.priority / 10).clamp(0.0, 1.0);
    final double learned = scoreForTask(task.title) * learningDepthFactor;
    final double deadlineBoost = task.hasDeadline ? 0.22 : 0;

    double hourAffinity = 0;
    final _TaskBehaviorMutable? score = _scores[task.title];
    final int? taskHour = score?.lastCompletedHour ?? preferredHour;
    if (taskHour != null) {
      final int distance = (hour - taskHour).abs();
      hourAffinity = (1 - (distance / 12)).clamp(0.0, 1.0) * 0.18;
    }

    return basePriority + (learned * historyFactor) + deadlineBoost + hourAffinity;
  }
}

class _TaskBehaviorMutable {
  _TaskBehaviorMutable({required this.taskTitle});

  final String taskTitle;
  int completedCount = 0;
  int skippedCount = 0;
  int delayedCount = 0;
  int? lastCompletedHour;
  double completionRate = 0;
  double skipRate = 0;
  double priorityScore = 0;

  TaskBehaviorScore freeze() {
    return TaskBehaviorScore(
      taskTitle: taskTitle,
      priorityScore: priorityScore,
      completionRate: completionRate,
      skipRate: skipRate,
      completedCount: completedCount,
      skippedCount: skippedCount,
      delayedCount: delayedCount,
      lastCompletedHour: lastCompletedHour,
    );
  }

  factory _TaskBehaviorMutable.fromFrozen(TaskBehaviorScore score) {
    return _TaskBehaviorMutable(taskTitle: score.taskTitle)
      ..priorityScore = score.priorityScore
      ..completionRate = score.completionRate
      ..skipRate = score.skipRate
      ..completedCount = score.completedCount
      ..skippedCount = score.skippedCount
      ..delayedCount = score.delayedCount
      ..lastCompletedHour = score.lastCompletedHour;
  }
}
