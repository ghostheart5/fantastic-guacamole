class AuthAuditEvent {
  const AuthAuditEvent({
    required this.action,
    required this.actorId,
    required this.timestamp,
    this.targetId,
    this.reason,
    this.metadata = const <String, Object?>{},
  });

  final String action;
  final String actorId;
  final DateTime timestamp;
  final String? targetId;
  final String? reason;
  final Map<String, Object?> metadata;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'action': action,
      'actorId': actorId,
      'timestamp': timestamp.toIso8601String(),
      'targetId': targetId,
      'reason': reason,
      'metadata': metadata,
    };
  }
}
