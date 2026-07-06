// lib/engine/si/si_multiverse_bridge_v2.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIMultiversePath {
  const SIMultiversePath({
    required this.name,
    required this.action,
    required this.message,
    required this.score,
    required this.reason,
  });

  final String name;
  final String action;
  final String message;
  final double score;
  final String reason;
}

class SIMultiverseBridgeResult {
  const SIMultiverseBridgeResult({
    required this.paths,
    required this.selected,
    required this.influenceScore,
    required this.memory,
  });

  final List<SIMultiversePath> paths;
  final SIMultiversePath selected;
  final double influenceScore;
  final SIMemoryStore memory;
}

class SIMultiverseBridgeV2 {
  const SIMultiverseBridgeV2();

  SIMultiverseBridgeResult blend({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    SIDecision? decision,
    SIResponse? response,
    DateTime? now,
  }) {
    final DateTime t = now ?? DateTime.now();
    final List<SIMultiversePath> paths = <SIMultiversePath>[
      _path(
        'safety',
        'respond_conversationally',
        'Let’s keep this simple and choose one small step.',
        instinct.safetyFirst ? 0.92 : 0.35,
        'Safety-first alternate path.',
      ),
      _path(
        'action',
        _action(intent.primary.label),
        response?.message ??
            decision?.reasoning ??
            'Choose one useful next action.',
        intent.confidence,
        'Action-oriented alternate path.',
      ),
      _path(
        'clarity',
        'ask_clarification',
        'I can help better with one detail: what outcome matters most right now?',
        instinct.reduceConfusion ? 0.82 : 0.42,
        'Clarification alternate path.',
      ),
    ];

    paths.sort(
      (SIMultiversePath a, SIMultiversePath b) => b.score.compareTo(a.score),
    );
    final SIMultiversePath selected = paths.first;

    final SIMemoryStore next = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content:
                'multiverse_v2|selected=${selected.name}|action=${selected.action}|reason=${selected.reason}',
            timestamp: t,
            relevance: selected.score,
            confidence: 0.72,
            emotionalWeight: instinct.safetyFirst ? 0.65 : 0.35,
            reinforcement: selected.score >= 0.7 ? 1 : 0,
          ),
        )
        .dedupe()
        .decay(t);

    return SIMultiverseBridgeResult(
      paths: List<SIMultiversePath>.unmodifiable(paths),
      selected: selected,
      influenceScore: siClamp01(selected.score),
      memory: next,
    );
  }

  String influenceMessage(String message, SIMultiverseBridgeResult result) {
    if (result.influenceScore < 0.65) return siClean(message);
    if (result.selected.name == 'safety') return result.selected.message;
    return siClean(message, fallback: result.selected.message);
  }

  SIMultiversePath _path(
    String name,
    String action,
    String message,
    double score,
    String reason,
  ) {
    return SIMultiversePath(
      name: name,
      action: action,
      message: siClean(message, fallback: 'Choose one small next step.'),
      score: siClamp01(score),
      reason: reason,
    );
  }

  String _action(String intent) {
    switch (intent) {
      case 'start_focus':
        return 'launch_focus_session';
      case 'get_task':
        return 'present_task_recommendation';
      case 'reflect':
        return 'open_reflection_flow';
      case 'insight_request':
        return 'show_insight_summary';
      default:
        return 'respond_conversationally';
    }
  }
}
