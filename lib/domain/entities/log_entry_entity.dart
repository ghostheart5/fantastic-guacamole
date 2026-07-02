class LogEntryEntity {
  const LogEntryEntity({
    required this.id,
    required this.message,
    required this.source,
    required this.timestamp,
  });

  final String id;
  final String message;
  final String source;
  final DateTime timestamp;
}
