/// CHRONOSPARK-CLASS: SHIPPING | Feature: Logs
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
  Duration ageAt(DateTime reference) => reference.difference(timestamp);

  Duration get age => ageAt(DateTime.now());

  bool isRecentAt(DateTime reference) => ageAt(reference).inMinutes < 5;

  bool get isRecent => isRecentAt(DateTime.now());

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
