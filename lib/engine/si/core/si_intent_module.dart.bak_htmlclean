// lib/engine/si/core/si_intent_module.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIIntentModule {
  const SIIntentModule();

  SIIntent extract(SIContext context) {
    final String text = _combinedText(context);
    final String normalized = _normalize(text);

    IntentCandidate primary = const IntentCandidate(
      label: 'general_query',
      score: 0.5,
      why: 'Fallback classification',
    );

    IntentCandidate? secondary;
    IntentCandidate? hidden;

    if (_containsAny(normalized, const <String>[
      'start focus',
      'focus now',
      'begin focus',
      'focus session',
      'deep work',
    ])) {
      primary = const IntentCandidate(
        label: 'start_focus',
        score: 0.86,
        why: 'Focus-session wording detected',
      );
      secondary = const IntentCandidate(
        label: 'productivity_optimization',
        score: 0.65,
        why: 'Focus implies performance optimization',
      );
    } else if (_containsAny(normalized, const <String>[
      'what should i do',
      'what now',
      'next task',
      'give me a task',
      'recommend task',
      'task',
    ])) {
      primary = const IntentCandidate(
        label: 'get_task',
        score: 0.82,
        why: 'User is asking for a next action',
      );
      hidden = const IntentCandidate(
        label: 'decision_support',
        score: 0.6,
        why: 'Likely seeking direction or confidence',
      );
    } else if (_containsAny(normalized, const <String>[
      'reflect',
      'review',
      'look back',
      'recap',
      'what happened',
    ])) {
      primary = const IntentCandidate(
        label: 'reflect',
        score: 0.8,
        why: 'Reflection or review wording detected',
      );
    } else if (_containsAny(normalized, const <String>[
      'insight',
      'pattern',
      'why',
      'analyze',
      'summary',
    ])) {
      primary = const IntentCandidate(
        label: 'insight_request',
        score: 0.78,
        why: 'Insight or analysis wording detected',
      );
    }

    final List<String> chain = <String>[
      primary.label,
      if (secondary != null) secondary.label,
      if (hidden != null) hidden.label,
    ];

    return SIIntent(
      primary: primary,
      secondary: secondary,
      hidden: hidden,
      predictedNext: _predictNext(primary.label),
      chain: List<String>.unmodifiable(chain),
    );
  }

  String _combinedText(SIContext context) {
    final String typed = context.input.text;
    final String voice = context.input.nonText.voiceToText ?? '';
    return '$typed $voice'.trim();
  }

  String _normalize(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _containsAny(String text, List<String> patterns) {
    return patterns.any((String p) => text.contains(p));
  }

  String _predictNext(String intent) {
    switch (intent) {
      case 'get_task':
        return 'start_focus';
      case 'start_focus':
        return 'insight_request';
      case 'reflect':
        return 'insight_request';
      case 'insight_request':
        return 'start_focus';
      default:
        return 'get_task';
    }
  }
}
