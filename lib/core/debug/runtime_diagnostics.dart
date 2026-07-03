import 'package:flutter/foundation.dart';

class RuntimeDiagnosticEvent {
  const RuntimeDiagnosticEvent({
    required this.timestamp,
    required this.category,
    required this.message,
    required this.data,
  });

  final DateTime timestamp;
  final String category;
  final String message;
  final Map<String, Object?> data;
}

class RuntimeDiagnostics {
  RuntimeDiagnostics._();

  static const int _maxEntries = 200;
  static final ValueNotifier<List<String>> entries =
      ValueNotifier<List<String>>(<String>[]);
  static final ValueNotifier<List<RuntimeDiagnosticEvent>> events =
      ValueNotifier<List<RuntimeDiagnosticEvent>>(<RuntimeDiagnosticEvent>[]);

  static void record(String message) {
    final String text = message.trim();
    if (text.isEmpty) return;

    final String stamped = '[${DateTime.now().toIso8601String()}] $text';
    final List<String> next = List<String>.from(entries.value)..add(stamped);
    if (next.length > _maxEntries) {
      next.removeRange(0, next.length - _maxEntries);
    }
    entries.value = next;
  }

  static void recordState(
    String category, {
    String message = '',
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    final DateTime now = DateTime.now();
    final RuntimeDiagnosticEvent event = RuntimeDiagnosticEvent(
      timestamp: now,
      category: category.trim(),
      message: message.trim(),
      data: Map<String, Object?>.unmodifiable(data),
    );

    final List<RuntimeDiagnosticEvent> nextEvents =
        List<RuntimeDiagnosticEvent>.from(events.value)..add(event);
    if (nextEvents.length > _maxEntries) {
      nextEvents.removeRange(0, nextEvents.length - _maxEntries);
    }
    events.value = nextEvents;

    final String summary = _summary(event);
    final List<String> nextEntries = List<String>.from(entries.value)
      ..add(summary);
    if (nextEntries.length > _maxEntries) {
      nextEntries.removeRange(0, nextEntries.length - _maxEntries);
    }
    entries.value = nextEntries;
  }

  static String _summary(RuntimeDiagnosticEvent event) {
    final String timestamp = event.timestamp.toIso8601String();
    final String scoped = event.category.isEmpty ? 'runtime' : event.category;
    final String body = event.message.isEmpty ? 'state updated' : event.message;
    final String payload = event.data.isEmpty
        ? ''
        : event.data.entries.map((e) => '${e.key}=${e.value}').join(', ');
    return payload.isEmpty
        ? '[$timestamp][$scoped] $body'
        : '[$timestamp][$scoped] $body | $payload';
  }
}
