// lib/engine/si/si_synthetic_language_generator.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/ai_personality.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_load_balancer.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_style_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_presence_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_intuition.dart';

class SyntheticLanguageResult {
  const SyntheticLanguageResult({
    required this.message,
    required this.wasChanged,
    required this.memory,
    required this.reason,
  });

  final String message;
  final bool wasChanged;
  final SIMemoryStore memory;
  final String reason;
}

class SISyntheticLanguageGenerator {
  const SISyntheticLanguageGenerator({
    this.styleEngine = const SICognitiveStyleEngine(),
  });

  final SICognitiveStyleEngine styleEngine;

  SyntheticLanguageResult refine({
    required String message,
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    AIPersonalityProfile? personality,
    PresenceProfile? presence,
    CognitiveLoadPlan? loadPlan,
    CognitiveStylePlan? stylePlan,
    SyntheticIntuitionResult? intuition,
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();
    String output = siClean(
      message,
      fallback: 'Tell me what you want to work on.',
    );

    output = _removePressure(output);
    output = _applyPersonality(output, personality, instinct);
    output = _applyPresence(output, presence);
    output = _applyIntuition(output, intuition, instinct);

    final CognitiveStylePlan plan =
        stylePlan ??
        styleEngine.plan(context: context, intent: intent, instinct: instinct);

    output = styleEngine.apply(message: output, plan: plan).text;

    if (loadPlan != null) {
      output = _limitWords(output, loadPlan.maxWords);
    }

    final bool changed = output.trim() != message.trim();

    final SIMemoryStore nextMemory = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content:
                'synthetic_language|changed=$changed|tone=${personality?.style.tone ?? plan.tone}|$output',
            timestamp: timestamp,
            relevance: changed ? 0.68 : 0.45,
            confidence: 0.72,
            emotionalWeight: instinct.safetyFirst ? 0.65 : 0.35,
            reinforcement: changed ? 1 : 0,
          ),
        )
        .dedupe()
        .decay(timestamp);

    return SyntheticLanguageResult(
      message: output,
      wasChanged: changed,
      memory: nextMemory,
      reason: changed
          ? 'Language refined for tone, load, and safety.'
          : 'Language already acceptable.',
    );
  }

  String _removePressure(String text) {
    return text
        .replaceAll(RegExp(r'\byou must\b', caseSensitive: false), 'you can')
        .replaceAll(RegExp(r'\bhave to\b', caseSensitive: false), 'can')
        .replaceAll(RegExp(r'\bshould\b', caseSensitive: false), 'could')
        .replaceAll(
          RegExp(r'\blazy\b|\bfailure\b|\bworthless\b', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _applyPersonality(
    String text,
    AIPersonalityProfile? personality,
    InstinctGuidance instinct,
  ) {
    if (personality == null) return text;
    if (instinct.safetyFirst || personality.style.pressureLevel <= 0.12) {
      return '$text\n\nOne small step is enough.';
    }
    if (personality.style.useSteps && !text.contains('\n')) {
      return text;
    }
    return text;
  }

  String _applyPresence(String text, PresenceProfile? presence) {
    if (presence == null) return text;
    if (presence.mode == PresenceMode.quiet &&
        !text.contains('One small step')) {
      return '$text\n\nOne small step.';
    }
    if (presence.mode == PresenceMode.steady && !text.contains('clear')) {
      return '$text\n\nI’ll keep this clear.';
    }
    return text;
  }

  String _applyIntuition(
    String text,
    SyntheticIntuitionResult? intuition,
    InstinctGuidance instinct,
  ) {
    if (intuition == null) return text;
    if (instinct.safetyFirst) return text;
    if (intuition.score < 0.5 && !text.contains('?')) {
      return '$text\n\nWant me to narrow this down?';
    }
    return text;
  }

  String _limitWords(String text, int maxWords) {
    final List<String> words = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .split(' ');
    if (words.length <= maxWords) return text.trim();
    return '${words.take(maxWords).join(' ')}...';
  }
}
