enum InterventionSeverity { low, medium, high }

/// A proposed, explainable user-facing action. It is not an outcome.
class Intervention {
  const Intervention({
    required this.id,
    required this.trigger,
    required this.reason,
    required this.evidence,
    required this.severity,
    required this.confidence,
    required this.suggestedAction,
    required this.createdAt,
    this.entityId,
    this.entityType,
  });

  final String id;
  final String trigger;
  final String reason;
  final List<String> evidence;
  final InterventionSeverity severity;
  final double confidence;
  final String suggestedAction;
  final DateTime createdAt;
  final String? entityId;
  final String? entityType;

  void validate() {
    if (id.trim().isEmpty || trigger.trim().isEmpty || reason.trim().isEmpty) {
      throw StateError('Intervention requires id, trigger, and reason.');
    }
    if (suggestedAction.trim().isEmpty) {
      throw StateError('Intervention requires a suggested action.');
    }
    if (confidence < 0 || confidence > 1) {
      throw StateError('Intervention confidence must be between 0 and 1.');
    }
  }
}
