import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';

class LogEntryRecord {
  const LogEntryRecord({
    required this.id,
    required this.message,
    required this.source,
    required this.timestamp,
  });

  final String id;
  final String message;
  final String source;
  final DateTime timestamp;

  factory LogEntryRecord.fromEntity(LogEntryEntity entity) {
    return LogEntryRecord(
      id: entity.id,
      message: entity.message,
      source: entity.source,
      timestamp: entity.timestamp,
    );
  }

  factory LogEntryRecord.fromJson(Map<String, dynamic> json) {
    final String id = json['id']?.toString().trim() ?? '';
    final String message = json['message']?.toString().trim() ?? '';
    final String source = json['source']?.toString().trim() ?? '';
    final DateTime? timestamp = DateTime.tryParse(
      json['timestamp']?.toString() ?? '',
    );
    if (id.isEmpty || message.isEmpty || source.isEmpty || timestamp == null) {
      throw const FormatException('Invalid log entry record.');
    }
    return LogEntryRecord(
      id: id,
      message: message,
      source: source,
      timestamp: timestamp,
    );
  }

  LogEntryEntity toEntity() {
    return LogEntryEntity(
      id: id,
      message: message,
      source: source,
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'message': message,
    'source': source,
    'timestamp': timestamp.toUtc().toIso8601String(),
  };
}
