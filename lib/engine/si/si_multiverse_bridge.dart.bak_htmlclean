// lib/engine/si/si_multiverse_bridge.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_intent.dart';

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
    required this.memory,
  });

  final List<SIMultiversePath> paths;
  final SIMultiversePath selected;
  final SIMemoryStore memory;
}

class SIMultiverseBridge {
  const SIMultiverseBridge({this.intentUtils = const SIIntentUtils()});

  final SIIntentUtils intentUtils;

  SIMultiverseBridgeResult evaluate({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    SIDecision? decision,
    SIResponse? response,
    DateTime? now,
  }) {
    final DateTime t = now ?? DateTime.now();
    final List<SIMultiversePath> paths =
        <SIMultiversePath>[
          SIMultiversePath(
            name: 'safety',
            action: 'respond_conversationally',
            message: 'Let’s keep this simple: choose one small next step.',
            score: instinct.safetyFirst ? .94 : .35,
            reason: 'Safety path.',
          ),
          SIMultiversePath(
            name: 'action',
            action:
                decision?.action ?? intentUtils.actionFor(intent.primary.label),
            message:
                response?.message ??
                decision?.reasoning ??
                'Choose one useful next action.',
            score: siClamp01(intent.confidence),
            reason: 'Action path.',
          ),
          SIMultiversePath(
            name: 'clarity',
            action: 'ask_clarification',
            message: 'What outcome matters most right now?',
            score: instinct.reduceConfusion ? .82 : .42,
            reason: 'Clarification path.',
          ),
        ]..sort(
          (SIMultiversePath a, SIMultiversePath b) =>
              b.score.compareTo(a.score),
        );

    final SIMultiversePath selected = paths.first;
    final SIMemoryStore next = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content:
                'multiverse|selected=${selected.name}|action=${selected.action}',
            timestamp: t,
            relevance: selected.score,
            confidence: .72,
            emotionalWeight: instinct.safetyFirst ? .65 : .35,
            reinforcement: selected.score >= .7 ? 1 : 0,
          ),
        )
        .dedupe()
        .decay(t);

    return SIMultiverseBridgeResult(
      paths: List<SIMultiversePath>.unmodifiable(paths),
      selected: selected,
      memory: next,
    );
  }
}
