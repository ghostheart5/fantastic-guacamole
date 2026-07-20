class AuthAnalyticsEvent {
  const AuthAnalyticsEvent({
    required this.name,
    required this.timestamp,
    this.userId,
    this.provider,
    this.success = true,
    this.parameters = const <String, Object?>{},
  });

  final String name;
  final DateTime timestamp;
  final String? userId;
  final String? provider;
  final bool success;
  final Map<String, Object?> parameters;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'name': name,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
      'provider': provider,
      'success': success,
      'parameters': parameters,
    };
  }
}
