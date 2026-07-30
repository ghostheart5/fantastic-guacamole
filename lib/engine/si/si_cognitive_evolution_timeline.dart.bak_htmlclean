// lib/engine/si/si_cognitive_evolution_timeline.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_interfaces.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_ecosystem_layer.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_micro_pattern_engine.dart';

enum EvolutionEventType {
  milestone,
  regression,
  stabilization,
  pattern,
  ecosystem,
}

class EvolutionEvent {
  const EvolutionEvent({
    required this.type,
    required this.label,
    required this.timestamp,
    required this.strength,
    required this.details,
  });

  final EvolutionEventType type;
  final String label;
  final DateTime timestamp;
  final double strength;
  final Map<String, dynamic> details;
}

class EvolutionTimeline {
  const EvolutionTimeline({this.events = const <EvolutionEvent>[]});

  final List<EvolutionEvent> events;

  EvolutionTimeline push(EvolutionEvent event, {int max = 120}) {
    return EvolutionTimeline(
      events: List<EvolutionEvent>.unmodifiable(
        <EvolutionEvent>[event, ...events].take(max),
      ),
    );
  }
}

class EvolutionTimelineUpdate {
  const EvolutionTimelineUpdate({
    required this.timeline,
    required this.memory,
    required this.summary,
  });

  final EvolutionTimeline timeline;
  final SIMemoryStore memory;
  final String summary;
}

class SICognitiveEvolutionTimelineEngine implements AssistantTimelineEngine {
  const SICognitiveEvolutionTimelineEngine();

  @override
  EvolutionTimelineUpdate track({
    required EvolutionTimeline current,
    required SIMemoryStore memory,
    required SIContext context,
    MicroPatternReport? patterns,
    SIEcosystemState? ecosystem,
    SIDecision? decision,
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();
    EvolutionTimeline timeline = current;

    final EvolutionEvent stateEvent = _stateEvent(context, timestamp);
    timeline = timeline.push(stateEvent);

    if (patterns != null && patterns.patterns.isNotEmpty) {
      final MicroPattern strongest = patterns.patterns.first;
      timeline = timeline.push(
        EvolutionEvent(
          type: EvolutionEventType.pattern,
          label: strongest.label,
          timestamp: timestamp,
          strength: strongest.strength,
          details: strongest.toJson(),
        ),
      );
    }

    if (ecosystem != null) {
      timeline = timeline.push(
        EvolutionEvent(
          type: EvolutionEventType.ecosystem,
          label: 'Ecosystem snapshot',
          timestamp: timestamp,
          strength: siClamp01(ecosystem.nodes.length / 24),
          details: <String, dynamic>{
            'nodes': ecosystem.nodes.length,
            'edges': ecosystem.edges.length,
          },
        ),
      );
    }

    if (decision != null && decision.safe && decision.confidence >= 0.75) {
      timeline = timeline.push(
        EvolutionEvent(
          type: EvolutionEventType.milestone,
          label: 'High-confidence safe decision',
          timestamp: timestamp,
          strength: decision.confidence,
          details: <String, dynamic>{'action': decision.action},
        ),
      );
    }

    final SIMemoryStore nextMemory = memory
        .pushRecord(
          MemoryTier.longTerm,
          MemoryRecord(
            content:
                'evolution_timeline|${timeline.events.first.type.name}|${timeline.events.first.label}',
            timestamp: timestamp,
            relevance: timeline.events.first.strength,
            confidence: 0.7,
            recency: 1.0,
            emotionalWeight: siClamp01(context.userState.stress),
            reinforcement:
                timeline.events.first.type == EvolutionEventType.milestone
                ? 2
                : 1,
          ),
        )
        .dedupe()
        .decay(timestamp);

    return EvolutionTimelineUpdate(
      timeline: timeline,
      memory: nextMemory,
      summary: _summary(timeline),
    );
  }

  EvolutionEvent _stateEvent(SIContext context, DateTime timestamp) {
    final SIUserState u = context.userState;

    if (u.stress >= 0.7 || u.cognitiveLoad >= 0.75) {
      return EvolutionEvent(
        type: EvolutionEventType.regression,
        label: 'High load state',
        timestamp: timestamp,
        strength: siClamp01((u.stress + u.cognitiveLoad) / 2),
        details: u.toJson(),
      );
    }

    if (u.engagement >= 0.65 && u.fatigue <= 0.45) {
      return EvolutionEvent(
        type: EvolutionEventType.stabilization,
        label: 'Stable engagement state',
        timestamp: timestamp,
        strength: siClamp01((u.engagement + (1 - u.fatigue)) / 2),
        details: u.toJson(),
      );
    }

    return EvolutionEvent(
      type: EvolutionEventType.stabilization,
      label: 'Neutral state update',
      timestamp: timestamp,
      strength: 0.5,
      details: u.toJson(),
    );
  }

  String _summary(EvolutionTimeline timeline) {
    if (timeline.events.isEmpty) return 'No timeline events yet.';
    return timeline.events
        .take(3)
        .map((EvolutionEvent e) => e.label)
        .join(' · ');
  }
}
