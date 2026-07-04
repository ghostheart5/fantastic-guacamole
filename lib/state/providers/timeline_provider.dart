import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final timelineProvider =
    NotifierProvider<TimelineNotifier, List<TimelineEventEntity>>(
      TimelineNotifier.new,
    );

class TimelineNotifier extends Notifier<List<TimelineEventEntity>> {
  static const _key = 'timeline_events_v1';
  static const _maxEvents = 500;

  @override
  List<TimelineEventEntity> build() {
    final raw = SharedPrefsService.load(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => TimelineEventEntity.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> record(TimelineEventEntity event) async {
    final updated = [event, ...state];
    state = updated.length > _maxEvents
        ? updated.sublist(0, _maxEvents)
        : updated;
    await _persist();
  }

  Future<void> _persist() async {
    await SharedPrefsService.save(
      _key,
      jsonEncode(state.map((e) => e.toJson()).toList()),
    );
  }
}
