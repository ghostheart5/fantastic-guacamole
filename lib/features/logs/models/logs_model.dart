import 'package:flutter/foundation.dart';

@immutable
class LogEntry {
  final String id;
  final DateTime timestamp;
  final String category; // e.g. "task", "focus", "system"
  final String message;
  final Map<String, dynamic>? metadata;

  const LogEntry({
    required this.id,
    required this.timestamp,
    required this.category,
    required this.message,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'category': category,
      'message': message,
      'metadata': metadata,
    };
  }

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      category: json['category'] as String,
      message: json['message'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
