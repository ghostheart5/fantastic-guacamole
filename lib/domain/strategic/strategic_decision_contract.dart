import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';

/// Stable, inspectable input to the local Strategic Intelligence decision path.
///
/// This is deliberately separate from presentation copy and remote-model
/// payloads.  Every recommendation can therefore record what facts it used.
class StrategicDecisionRequest {
  const StrategicDecisionRequest({
    required this.state,
    required this.tasks,
    required this.createdAt,
    this.userIntent,
    this.signals = const <StrategicDecisionSignal>[],
    this.maxSuggestions = 3,
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  final SiStateEntity state;
  final List<TaskEntity> tasks;
  final DateTime createdAt;
  final String? userIntent;
  final List<StrategicDecisionSignal> signals;
  final int maxSuggestions;
  final int schemaVersion;

  bool get isOverloaded =>
      state.avoidOverwhelm || state.isHighFrictionState || state.isFatigued;

  void validate() {
    state.validate();
    if (schemaVersion != currentSchemaVersion) {
      throw StateError('Unsupported Strategic Intelligence request version.');
    }
    if (maxSuggestions < 1 || maxSuggestions > 5) {
      throw StateError(
        'Strategic Intelligence supports one to five suggestions.',
      );
    }
    for (final StrategicDecisionSignal signal in signals) {
      signal.validate();
    }
  }
}

enum StrategicDecisionSignalKind {
  userIntent,
  energy,
  focus,
  fatigue,
  friction,
  schedule,
  completionHistory,
  preference,
}

class StrategicDecisionSignal {
  const StrategicDecisionSignal({
    required this.kind,
    required this.source,
    required this.recordedAt,
    this.value,
    this.subjectId,
  });

  final StrategicDecisionSignalKind kind;
  final String source;
  final DateTime recordedAt;
  final String? value;
  final String? subjectId;

  void validate() {
    if (source.trim().isEmpty) {
      throw StateError('Strategic Intelligence signals require a source.');
    }
  }
}

class StrategicDecisionEvidence {
  const StrategicDecisionEvidence({
    required this.code,
    required this.description,
    this.taskId,
    this.weight,
  });

  final String code;
  final String description;
  final String? taskId;
  final double? weight;
}

/// A versioned recommendation receipt suitable for persistence, analytics, or
/// a future remote intelligence adapter. It never exposes private raw input.
class StrategicDecisionReceipt {
  const StrategicDecisionReceipt({
    required this.decision,
    required this.generatedAt,
    required this.expiresAt,
    required this.evidence,
    required this.requestSchemaVersion,
    this.isFallback = false,
    this.engine = 'local-deterministic-v1',
  });

  final SiDecisionEntity decision;
  final DateTime generatedAt;
  final DateTime expiresAt;
  final List<StrategicDecisionEvidence> evidence;
  final int requestSchemaVersion;
  final bool isFallback;
  final String engine;

  bool get isExpired => !expiresAt.isAfter(DateTime.now());

  void validate() {
    decision.validate();
    if (!expiresAt.isAfter(generatedAt)) {
      throw StateError(
        'Strategic Intelligence receipts require a future expiry.',
      );
    }
    if (requestSchemaVersion != StrategicDecisionRequest.currentSchemaVersion) {
      throw StateError('Strategic Intelligence receipt version mismatch.');
    }
  }
}
