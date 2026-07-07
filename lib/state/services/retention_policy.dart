class RetentionPolicy {
  const RetentionPolicy({
    required this.sessionMaxAge,
    required this.staleNotificationAge,
    required this.hygieneInterval,
  });

  final Duration sessionMaxAge;
  final Duration staleNotificationAge;
  final Duration hygieneInterval;

  static const RetentionPolicy standard = RetentionPolicy(
    sessionMaxAge: Duration(days: 7),
    staleNotificationAge: Duration(days: 14),
    hygieneInterval: Duration(hours: 6),
  );

  bool isSessionExpired(DateTime timestamp, {DateTime? now}) {
    final DateTime ref = now ?? DateTime.now();
    return timestamp.isBefore(ref.subtract(sessionMaxAge));
  }

  bool isNotificationStale(DateTime scheduledAt, {DateTime? now}) {
    final DateTime ref = now ?? DateTime.now();
    return scheduledAt.isBefore(ref.subtract(staleNotificationAge));
  }
}
