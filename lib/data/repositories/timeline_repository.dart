import 'dart:convert';

import 'package:fantastic_guacamole/core/errors/app_exception.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/history/history_event.dart';
import 'package:fantastic_guacamole/domain/history/timeline_history_adapter.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class TimelineRepository implements ITimelineRepository {
  TimelineRepository(this._store, AccountStorageScope scope)
    : _key = _scopedKey(scope);

  TimelineRepository.unavailable(this._store) : _key = null;

  final SharedPrefsStore _store;
  final String? _key;

  static String _scopedKey(AccountStorageScope scope) {
    final String? namespace = scope.v2Namespace;
    if (namespace == null) throw StateError('Timeline storage is unavailable.');
    return 'timeline_events_v2.$namespace';
  }

  String get _storageKey {
    final String? key = _key;
    if (key == null) throw StateError('Timeline storage is unavailable.');
    return key;
  }

  @override
  List<TimelineEventEntity> getEvents() {
    return getHistoryEvents()
        .map(TimelineHistoryAdapter.toTimeline)
        .toList(growable: false);
  }

  /// Canonical durable history; Timeline remains a compatibility read model.
  List<HistoryEvent> getHistoryEvents() {
    final String? raw = _store.load(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <HistoryEvent>[];
    }
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      final List<HistoryEvent> events = list
          .whereType<Map<String, dynamic>>()
          .map(_decodeHistory)
          .toList(growable: false);
      return <HistoryEvent>[...events]..sort(
        (HistoryEvent a, HistoryEvent b) =>
            b.occurredAt.compareTo(a.occurredAt),
      );
    } on Object catch (error) {
      throw StorageException('Timeline storage is corrupted: $error');
    }
  }

  @override
  Future<void> addEvent(TimelineEventEntity event) {
    final List<TimelineEventEntity> next = <TimelineEventEntity>[
      event,
      ...getEvents(),
    ];
    return saveEvents(next);
  }

  @override
  Future<void> saveEvents(List<TimelineEventEntity> events) {
    return saveHistoryEvents(
      events.map(TimelineHistoryAdapter.toHistory).toList(growable: false),
    );
  }

  Future<void> saveHistoryEvents(List<HistoryEvent> events) {
    return _store.save(
      _storageKey,
      jsonEncode(events.map((HistoryEvent event) => event.toJson()).toList()),
    );
  }

  @override
  Future<void> removeEvent(String id) {
    final List<TimelineEventEntity> next = getEvents()
        .where((TimelineEventEntity event) => event.id != id)
        .toList(growable: false);
    return saveEvents(next);
  }

  HistoryEvent _decodeHistory(Map<String, dynamic> json) {
    if (json.containsKey('schemaVersion') && json.containsKey('occurredAt')) {
      return HistoryEvent.fromJson(json);
    }
    return TimelineHistoryAdapter.fromLegacyJson(json);
  }
}
