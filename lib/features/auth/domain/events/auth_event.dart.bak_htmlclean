class AuthEvent {
  const AuthEvent({
    required this.action,
    required this.timestamp,
    this.userId,
    this.provider,
    this.details = const <String, Object?>{},
  });

  final String action;
  final DateTime timestamp;
  final String? userId;
  final String? provider;
  final Map<String, Object?> details;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'action': action,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
      'provider': provider,
      'details': details,
    };
  }
}
