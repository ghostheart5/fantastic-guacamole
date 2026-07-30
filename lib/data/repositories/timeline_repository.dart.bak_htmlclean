import 'dart:convert';

import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class TimelineRepository implements ITimelineRepository {
  TimelineRepository(this._store);

  static const String _key = 'timeline_events_v1';

  final SharedPrefsStore _store;

  @override
  List<TimelineEventEntity> getEvents() {
    final String? raw = _store.load(_key);
    if (raw == null || raw.trim().isEmpty) {
      return const <TimelineEventEntity>[];
    }
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(TimelineEventEntity.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const <TimelineEventEntity>[];
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
    return _store.save(
      _key,
      jsonEncode(events.map((TimelineEventEntity e) => e.toJson()).toList()),
    );
  }

  @override
  Future<void> removeEvent(String id) {
    final List<TimelineEventEntity> next = getEvents()
        .where((TimelineEventEntity event) => event.id != id)
        .toList(growable: false);
    return saveEvents(next);
  }
}
