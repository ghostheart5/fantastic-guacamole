import 'dart:convert';

import 'package:fantastic_guacamole/core/errors/app_exception.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/completion_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_completion_event_repository.dart';

class CompletionEventRepository implements ICompletionEventRepository {
  CompletionEventRepository(this._store, AccountStorageScope scope)
    : _key = _scopedKey(scope);

  CompletionEventRepository.unavailable(this._store) : _key = null;

  final SharedPrefsStore _store;
  final String? _key;
  Future<void> _writeTail = Future<void>.value();

  static String _scopedKey(AccountStorageScope scope) {
    final String? namespace = scope.v2Namespace;
    if (namespace == null) {
      throw StateError('Completion storage is unavailable.');
    }
    return 'completion_events_v2.$namespace';
  }

  String get _storageKey {
    final String? key = _key;
    if (key == null) throw StateError('Completion storage is unavailable.');
    return key;
  }

  @override
  List<CompletionEventEntity> getEvents() {
    final String? raw = _store.load(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <CompletionEventEntity>[];
    }

    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(CompletionEventEntity.fromJson)
          .toList(growable: false);
    } on Object catch (error) {
      throw StorageException('Completion event storage is corrupted: $error');
    }
  }

  @override
  Future<void> addEvent(CompletionEventEntity event) =>
      _serializeWrite(() async {
        final List<CompletionEventEntity> current = getEvents();
        if (current.any((CompletionEventEntity item) => item.id == event.id)) {
          return;
        }
        await saveEvents(<CompletionEventEntity>[event, ...current]);
      });

  @override
  Future<void> saveEvents(List<CompletionEventEntity> events) {
    return _store.save(
      _storageKey,
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

  Future<void> _serializeWrite(Future<void> Function() action) {
    final Future<void> next = _writeTail.then((_) => action());
    _writeTail = next.catchError((Object _) {});
    return next;
  }
}
