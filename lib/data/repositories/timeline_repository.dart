import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class TimelineRepository
    implements ITimelineRepository, IAtomicTimelineRepository {
  TimelineRepository(this._store);

  static const String _key = 'timeline_events_v1';
  static const String _corruptBackupKey = 'timeline_events_v1_corrupt_backup';

  final SharedPrefsStore _store;
  Future<void> _writeTail = Future<void>.value();
  bool _lastReadCorrupted = false;
  String? _corruptRaw;

  @override
  bool get lastReadCorrupted => _lastReadCorrupted;

  @override
  List<TimelineEventEntity> getEvents() {
    final String? raw = _store.load(_key);
    if (raw == null || raw.trim().isEmpty) {
      _clearCorruptionState();
      return const <TimelineEventEntity>[];
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        throw const FormatException('Timeline payload is not a list.');
      }
      final List<TimelineEventEntity> events = <TimelineEventEntity>[];
      bool rejectedEntry = false;
      for (final Object? entry in decoded) {
        if (entry is! Map<String, dynamic>) {
          rejectedEntry = true;
          continue;
        }
        try {
          _validateStoredEnumValues(entry);
          final TimelineEventEntity event = TimelineEventEntity.fromJson(entry);
          event.validate();
          events.add(event);
        } on Object {
          rejectedEntry = true;
        }
      }
      if (rejectedEntry) {
        _markCorrupted(raw);
        Logger.errorCategory(
          'StorageCorruption',
          'Stored Timeline activity contains unreadable records. Valid '
              'records remain available and the original payload is preserved.',
        );
      } else {
        _clearCorruptionState();
      }
      return List<TimelineEventEntity>.unmodifiable(events);
    } catch (error, stackTrace) {
      _markCorrupted(raw);
      Logger.errorCategory(
        'StorageCorruption',
        'Failed to decode stored Timeline activity. The unreadable payload '
            'was retained for recovery.',
        error,
        stackTrace,
      );
      return const <TimelineEventEntity>[];
    }
  }

  @override
  Future<void> addEvent(TimelineEventEntity event) {
    return _enqueueWrite(() async {
      final List<TimelineEventEntity> next = <TimelineEventEntity>[
        event,
        ...getEvents(),
      ];
      await _saveEventsUnlocked(next);
    });
  }

  @override
  Future<void> saveEvents(List<TimelineEventEntity> events) {
    final List<TimelineEventEntity> snapshot =
        List<TimelineEventEntity>.unmodifiable(events);
    return _enqueueWrite(() async {
      getEvents();
      await _saveEventsUnlocked(snapshot);
    });
  }

  @override
  Future<void> removeEvent(String id) {
    return _enqueueWrite(() async {
      final List<TimelineEventEntity> next = getEvents()
          .where((TimelineEventEntity event) => event.id != id)
          .toList(growable: false);
      await _saveEventsUnlocked(next);
    });
  }

  @override
  Future<TimelineEventEntity?> updateEvent(
    String id,
    TimelineEventEntity Function(TimelineEventEntity current) transform,
  ) {
    return _enqueueWrite(() async {
      final List<TimelineEventEntity> current = getEvents();
      final int index = current.indexWhere(
        (TimelineEventEntity event) => event.id == id,
      );
      if (index < 0) return null;
      final TimelineEventEntity updated = transform(current[index]);
      updated.validate();
      final List<TimelineEventEntity> next = current.toList(growable: true);
      next[index] = updated;
      await _saveEventsUnlocked(next);
      return updated;
    });
  }

  Future<void> _saveEventsUnlocked(List<TimelineEventEntity> events) async {
    for (final TimelineEventEntity event in events) {
      event.validate();
    }
    await _quarantineCorruptPayloadIfNeeded();
    await _store.save(
      _key,
      jsonEncode(events.map((TimelineEventEntity e) => e.toJson()).toList()),
    );
    _clearCorruptionState();
  }

  Future<void> _quarantineCorruptPayloadIfNeeded() async {
    if (!_lastReadCorrupted) {
      return;
    }
    final String? raw = _corruptRaw ?? _store.load(_key);
    if (raw == null || raw.trim().isEmpty) {
      throw StateError('Unreadable Timeline payload is no longer available.');
    }
    await _store.save(_corruptBackupKey, raw);
    Logger.errorCategory(
      'StorageCorruption',
      'Preserved unreadable Timeline activity before replacing the active '
          'payload.',
    );
  }

  Future<T> _enqueueWrite<T>(Future<T> Function() operation) {
    final Future<T> next = _writeTail.then<T>(
      (_) => operation(),
      onError: (Object _, StackTrace _) => operation(),
    );
    _writeTail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  void _markCorrupted(String raw) {
    _lastReadCorrupted = true;
    _corruptRaw = raw;
  }

  void _clearCorruptionState() {
    _lastReadCorrupted = false;
    _corruptRaw = null;
  }

  void _validateStoredEnumValues(Map<String, dynamic> entry) {
    final Object? type = entry['type'];
    if (type is! String ||
        !TimelineEventType.values.any(
          (TimelineEventType value) => value.name == type,
        )) {
      throw const FormatException('Unsupported Timeline event type.');
    }

    final Object? status = entry['status'];
    if (status != null &&
        (status is! String ||
            !TimelineEventStatus.values.any(
              (TimelineEventStatus value) => value.name == status,
            ))) {
      throw const FormatException('Unsupported Timeline event status.');
    }
  }
}
