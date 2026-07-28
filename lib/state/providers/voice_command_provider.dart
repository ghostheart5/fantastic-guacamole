import 'package:flutter_riverpod/flutter_riverpod.dart';

enum VoiceCommandIntent {
  createTask,
  createGoal,
  recordMemory,
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
  });

  final VoiceCommandIntent intent;
  final String originalText;
  final String normalizedText;
  final String confirmation;

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

  VoiceCommandResult _result({
    required VoiceCommandIntent intent,
    required String original,
    required String normalized,
    required String confirmation,
  }) {
    return VoiceCommandResult(
      intent: intent,
      originalText: original,
      normalizedText: normalized,
      confirmation: confirmation,
    );
  }
}

final voiceCommandParserProvider = Provider<VoiceCommandParser>((ref) {
  return const VoiceCommandParser();
});
