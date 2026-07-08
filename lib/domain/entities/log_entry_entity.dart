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

  // Domain behavior
  Duration get age => DateTime.now().difference(timestamp);

  bool get isRecent => age.inMinutes < 5;

  bool get isSystem => source == 'system';
  bool get isUser => source == 'user';
  bool get isError => source == 'error';

  bool contains(String text) =>
      message.toLowerCase().contains(text.toLowerCase());

  void validate() {
    if (message.trim().isEmpty) {
      throw StateError('LogEntryEntity must have a message');
    }
  }
}
