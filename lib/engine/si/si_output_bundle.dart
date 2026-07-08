// lib/engine/si/si_output_bundle.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIDebugTrace {
  const SIDebugTrace({
    required this.events,
    this.warnings = const <String>[],
    this.metadata = const <String, dynamic>{},
  });

  final List<String> events;
  final List<String> warnings;
  final Map<String, dynamic> metadata;

  factory SIDebugTrace.empty() => const SIDebugTrace(events: <String>[]);

  SIDebugTrace addEvent(String event) {
    return SIDebugTrace(
      events: List<String>.unmodifiable(<String>[...events, event]),
      warnings: warnings,
      metadata: metadata,
    );
  }

  SIDebugTrace addWarning(String warning) {
    return SIDebugTrace(
      events: events,
      warnings: List<String>.unmodifiable(<String>[...warnings, warning]),
      metadata: metadata,
    );
  }

  SIDebugTrace withMetadata(Map<String, dynamic> values) {
    return SIDebugTrace(
      events: events,
      warnings: warnings,
      metadata: Map<String, dynamic>.unmodifiable(<String, dynamic>{
        ...metadata,
        ...values,
      }),
    );
  }
}

class SIOutputBundle {
  const SIOutputBundle({
    required this.context,
    required this.intent,
    required this.instinct,
    required this.cognition,
    required this.decision,
    required this.response,
    required this.memory,
    required this.debugTrace,
  });

  final SIContext context;
  final SIIntent intent;
  final InstinctGuidance instinct;
  final SICognitionState cognition;
  final SIDecision decision;
  final SIResponse response;
  final SIMemoryUpdate memory;
  final SIDebugTrace debugTrace;

  bool get safe => decision.safe;
  String get message => response.message;
  SIMemoryStore get memoryStore => memory.store;
}
