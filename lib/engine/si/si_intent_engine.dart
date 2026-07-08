// lib/engine/si/si_intent_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_intent.dart';

class SIIntentEngine {
  const SIIntentEngine();

  SIIntent extract(SIContext context) {
    final String text =
        '${context.input.text} ${context.input.nonText.voiceToText ?? ''}'
            .toLowerCase()
            .replaceAll(RegExp(r'[^\w\s]'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

    IntentCandidate primary = const IntentCandidate(
      label: SIIntentLabels.generalQuery,
      score: .5,
      why: 'Fallback classification.',
    );
    IntentCandidate? secondary;
    IntentCandidate? hidden;

    if (_any(text, const <String>[
      'start focus',
      'focus now',
      'deep work',
      'focus session',
    ])) {
      primary = const IntentCandidate(
        label: SIIntentLabels.startFocus,
        score: .86,
        why: 'Focus wording detected.',
      );
      secondary = const IntentCandidate(
        label: SIIntentLabels.productivityOptimization,
        score: .64,
        why: 'Focus implies optimization.',
      );
    } else if (_any(text, const <String>[
      'what should i do',
      'next task',
      'what now',
      'give me a task',
      'task',
    ])) {
      primary = const IntentCandidate(
        label: SIIntentLabels.getTask,
        score: .82,
        why: 'Next-action request detected.',
      );
      hidden = const IntentCandidate(
        label: SIIntentLabels.decisionSupport,
        score: .6,
        why: 'User likely wants direction.',
      );
    } else if (_any(text, const <String>[
      'reflect',
      'review',
      'recap',
      'look back',
    ])) {
      primary = const IntentCandidate(
        label: SIIntentLabels.reflect,
        score: .8,
        why: 'Reflection wording detected.',
      );
    } else if (_any(text, const <String>[
      'insight',
      'pattern',
      'analyze',
      'why',
    ])) {
      primary = const IntentCandidate(
        label: SIIntentLabels.insightRequest,
        score: .78,
        why: 'Insight wording detected.',
      );
    }

    return SIIntent(
      primary: primary,
      secondary: secondary,
      hidden: hidden,
      predictedNext: _next(primary.label),
      chain: <String>[
        primary.label,
        if (secondary != null) secondary.label,
        if (hidden != null) hidden.label,
      ],
    );
  }

  bool _any(String text, List<String> patterns) => patterns.any(text.contains);

  String _next(String label) {
    switch (label) {
      case SIIntentLabels.getTask:
        return SIIntentLabels.startFocus;
      case SIIntentLabels.startFocus:
      case SIIntentLabels.reflect:
        return SIIntentLabels.insightRequest;
      case SIIntentLabels.insightRequest:
        return SIIntentLabels.startFocus;
      default:
        return SIIntentLabels.getTask;
    }
  }
}
