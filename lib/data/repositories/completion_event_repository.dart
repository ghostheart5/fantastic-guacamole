import 'dart:convert';

import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/completion_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_completion_event_repository.dart';

class CompletionEventRepository implements ICompletionEventRepository {
  CompletionEventRepository(this._store);

  static const String _key = 'completion_events_v1';

  final SharedPrefsStore _store;

  @override
  List<CompletionEventEntity> getEvents() {
    final String? raw = _store.load(_key);
    if (raw == null || raw.trim().isEmpty) {
      return const <CompletionEventEntity>[];
    }

    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(CompletionEventEntity.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const <CompletionEventEntity>[];
    }
  }

  @override
  Future<void> addEvent(CompletionEventEntity event) {
    final List<CompletionEventEntity> next = <CompletionEventEntity>[
      event,
      ...getEvents(),
    ];
    return saveEvents(next);
  }

  @override
  Future<void> saveEvents(List<CompletionEventEntity> events) {
    return _store.save(
      _key,
      jsonEncode(
        events
            .map((CompletionEventEntity event) => event.toJson())
            .toList(growable: false),
      ),
    );
  }

  @override
  Future<void> removeEvent(String id) {
    final List<CompletionEventEntity> next = getEvents()
        .where((CompletionEventEntity event) => event.id != id)
        .toList(growable: false);
    return saveEvents(next);
  }
}
