import 'package:flutter_riverpod/flutter_riverpod.dart';

enum VoiceCommandIntent {
  createTask,
  createGoal,
  createRoutine,
  createNote,
  recordMemory,
  showToday,
  showOverdue,
  completeTask,
  skipTask,
  moveTaskTomorrow,
  startFocusSession,
  replanDay,
  showTrajectory,
  showBriefing,
  nextMove,
  openCoach,
  openCreator,
  openTimeline,
  openProfile,
  openProgression,
  openSiConsole,
  unknown,
}

class VoiceCommandResult {
  const VoiceCommandResult({
    required this.intent,
    required this.originalText,
    required this.normalizedText,
    required this.confirmation,
    this.scheduleHint,
    this.frequencyHint,
    this.targetHint,
  });

  final VoiceCommandIntent intent;
  final String originalText;
  final String normalizedText;
  final String confirmation;
  final String? scheduleHint;
  final String? frequencyHint;
  final String? targetHint;

  bool get isKnown => intent != VoiceCommandIntent.unknown;
}

class VoiceCommandParser {
  const VoiceCommandParser();

  VoiceCommandResult parse(String input) {
    final String original = input.trim();
    final String normalized = original.toLowerCase();

    if (normalized.isEmpty) {
      return _result(
        intent: VoiceCommandIntent.unknown,
        original: original,
        normalized: normalized,
        confirmation: 'No voice command detected.',
      );
    }

    if (_containsAny(normalized, const <String>[
      'create task',
      'new task',
      'add task',
      'make task',
    ])) {
      return _result(
        intent: VoiceCommandIntent.createTask,
        original: original,
        normalized: normalized,
        confirmation: 'Opening Creator for task creation.',
      );
    }

    if (_containsAny(normalized, const <String>[
      'create goal',
      'new goal',
      'add goal',
      'make goal',
    ])) {
      return _result(
        intent: VoiceCommandIntent.createGoal,
        original: original,
        normalized: normalized,
        confirmation: 'Opening Creator for goal creation.',
      );
    }

    if (_containsAny(normalized, const <String>[
      'create routine',
      'new routine',
      'add routine',
      'make routine',
      'create habit',
      'new habit',
      'add habit',
      'make habit',
    ])) {
      return _result(
        intent: VoiceCommandIntent.createRoutine,
        original: original,
        normalized: normalized,
        confirmation: 'Opening Creator for routine creation.',
        scheduleHint: _extractScheduleHint(original),
        frequencyHint: _extractFrequencyHint(normalized),
      );
    }

    if (_containsAny(normalized, const <String>[
      'create note',
      'new note',
      'add note',
      'make note',
    ])) {
      return _result(
        intent: VoiceCommandIntent.createNote,
        original: original,
        normalized: normalized,
        confirmation: 'Opening Creator for note capture.',
      );
    }

    if (_containsAny(normalized, const <String>[
      'record memory',
      'save memory',
      'remember this',
      'capture memory',
    ])) {
      return _result(
        intent: VoiceCommandIntent.recordMemory,
        original: original,
        normalized: normalized,
        confirmation: 'Opening Creator for memory capture.',
        scheduleHint: _extractScheduleHint(original),
        frequencyHint: _extractFrequencyHint(normalized),
      );
    }

    if (_containsAny(normalized, const <String>[
      'show today',
      'what is due today',
      'what\'s due today',
      'today tasks',
      'today timeline',
    ])) {
      return _result(
        intent: VoiceCommandIntent.showToday,
        original: original,
        normalized: normalized,
        confirmation: 'Opening Timeline and summarizing what is due today.',
      );
    }

    if (_containsAny(normalized, const <String>[
      'show overdue',
      'what is overdue',
      'what\'s overdue',
      'overdue tasks',
    ])) {
      return _result(
        intent: VoiceCommandIntent.showOverdue,
        original: original,
        normalized: normalized,
        confirmation: 'Opening Timeline and summarizing overdue items.',
      );
    }

    if (_containsAny(normalized, const <String>[
      'mark task complete',
      'complete task',
      'mark complete',
      'done with task',
    ])) {
      return _result(
        intent: VoiceCommandIntent.completeTask,
        original: original,
        normalized: normalized,
        confirmation:
            'Opening Timeline. For safety, confirm completion in the UI before applying.',
        targetHint: _extractActionTarget(original),
      );
    }

    if (_containsAny(normalized, const <String>[
      'skip this item',
      'skip task',
      'mark task skipped',
    ])) {
      return _result(
        intent: VoiceCommandIntent.skipTask,
        original: original,
        normalized: normalized,
        confirmation:
            'Opening Timeline. For safety, confirm skip in the UI before applying.',
        targetHint: _extractActionTarget(original),
      );
    }

    if (_containsAny(normalized, const <String>[
      'move this task to tomorrow',
      'move task to tomorrow',
      'reschedule to tomorrow',
    ])) {
      return _result(
        intent: VoiceCommandIntent.moveTaskTomorrow,
        original: original,
        normalized: normalized,
        confirmation:
            'Opening Timeline. For safety, confirm the reschedule in the UI before applying.',
        targetHint: _extractActionTarget(original),
      );
    }

    if (_containsAny(normalized, const <String>[
      'start focus',
      'focus session',
      'begin focus',
      'start timer',
    ])) {
      return _result(
        intent: VoiceCommandIntent.startFocusSession,
        original: original,
        normalized: normalized,
        confirmation: 'Preparing focus session.',
      );
    }

    if (_containsAny(normalized, const <String>[
      'replan my day',
      'replan today',
      'plan my day',
      'fix my day',
    ])) {
      return _result(
        intent: VoiceCommandIntent.replanDay,
        original: original,
        normalized: normalized,
        confirmation: 'Opening Smart Planner for day replanning.',
      );
    }

    if (_containsAny(normalized, const <String>[
      'show trajectory',
      'open trajectory',
      'future vector',
      'future direction',
    ])) {
      return _result(
        intent: VoiceCommandIntent.showTrajectory,
        original: original,
        normalized: normalized,
        confirmation: 'Opening Future Vector.',
      );
    }

    if (_containsAny(normalized, const <String>[
      'daily briefing',
      'command briefing',
      'briefing',
      'today briefing',
    ])) {
      return _result(
        intent: VoiceCommandIntent.showBriefing,
        original: original,
        normalized: normalized,
        confirmation: 'Opening daily command briefing.',
      );
    }

    if (_containsAny(normalized, const <String>[
      'what should i do next',
      'next move',
      'best next move',
      'what now',
    ])) {
      return _result(
        intent: VoiceCommandIntent.nextMove,
        original: original,
        normalized: normalized,
        confirmation: 'Opening Smart Planner for your next move.',
      );
    }

    if (_containsAny(normalized, const <String>[
      'open coach',
      'smart coach',
      'coach',
    ])) {
      return _result(
        intent: VoiceCommandIntent.openCoach,
        original: original,
        normalized: normalized,
        confirmation: 'Opening Smart Planner.',
      );
    }

    if (_containsAny(normalized, const <String>[
      'open creator',
      'creator',
      'create something',
    ])) {
      return _result(
        intent: VoiceCommandIntent.openCreator,
        original: original,
        normalized: normalized,
        confirmation: 'Opening Creator.',
      );
    }

    if (_containsAny(normalized, const <String>[
      'open timeline',
      'timeline',
      'history',
    ])) {
      return _result(
        intent: VoiceCommandIntent.openTimeline,
        original: original,
        normalized: normalized,
        confirmation: 'Opening Timeline.',
      );
    }

    if (_containsAny(normalized, const <String>[
      'open profile',
      'profile',
      'operator profile',
    ])) {
      return _result(
        intent: VoiceCommandIntent.openProfile,
        original: original,
        normalized: normalized,
        confirmation: 'Opening Profile.',
      );
    }

    if (_containsAny(normalized, const <String>[
      'open progression',
      'progression',
      'ascension core',
      'ascension',
    ])) {
      return _result(
        intent: VoiceCommandIntent.openProgression,
        original: original,
        normalized: normalized,
        confirmation: 'Opening Ascension Core.',
      );
    }

    if (_containsAny(normalized, const <String>[
      'open si console',
      'strategic intelligence',
      'intelligence core',
      'si console',
    ])) {
      return _result(
        intent: VoiceCommandIntent.openSiConsole,
        original: original,
        normalized: normalized,
        confirmation: 'Opening Strategic Intelligence.',
      );
    }

    return _result(
      intent: VoiceCommandIntent.unknown,
      original: original,
      normalized: normalized,
      confirmation:
          'Voice command not recognized. Sending text to Smart Planner.',
    );
  }

  bool _containsAny(String value, List<String> patterns) {
    for (final String pattern in patterns) {
      if (value.contains(pattern)) {
        return true;
      }
    }
    return false;
  }

  String? _extractScheduleHint(String original) {
    final RegExp match = RegExp(
      r'\b(tomorrow|today|tonight|next\s+\w+|on\s+[^,.;]+|at\s+\d{1,2}(:\d{2})?\s*(am|pm)?)\b',
      caseSensitive: false,
    );
    final RegExpMatch? found = match.firstMatch(original);
    return found?.group(0)?.trim();
  }

  String? _extractFrequencyHint(String normalized) {
    final List<String> patterns = const <String>[
      'daily',
      'every day',
      'every weekday',
      'weekly',
      'every week',
      'monthly',
      'every month',
    ];
    for (final String pattern in patterns) {
      if (normalized.contains(pattern)) {
        return pattern;
      }
    }
    return null;
  }

  String? _extractActionTarget(String original) {
    final RegExp target = RegExp(
      r'\b(?:task|item)\s+(.+)$',
      caseSensitive: false,
    );
    final RegExpMatch? match = target.firstMatch(original.trim());
    final String? raw = match?.group(1)?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return raw;
  }

  VoiceCommandResult _result({
    required VoiceCommandIntent intent,
    required String original,
    required String normalized,
    required String confirmation,
    String? scheduleHint,
    String? frequencyHint,
    String? targetHint,
  }) {
    return VoiceCommandResult(
      intent: intent,
      originalText: original,
      normalizedText: normalized,
      confirmation: confirmation,
      scheduleHint: scheduleHint,
      frequencyHint: frequencyHint,
      targetHint: targetHint,
    );
  }
}

final voiceCommandParserProvider = Provider<VoiceCommandParser>((ref) {
  return const VoiceCommandParser();
});
