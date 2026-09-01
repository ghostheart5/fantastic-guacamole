import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_occurrence_repository.dart';

class HabitOccurrenceRepository implements IHabitOccurrenceRepository {
  HabitOccurrenceRepository(this._store, this._scope);

  final SharedPrefsStore _store;
  final AccountStorageScope _scope;
  Future<void> _tail = Future<void>.value();

  String get persistenceKey {
    final String? namespace = _scope.v2Namespace;
    if (!_scope.isWritable || namespace == null) {
      throw StateError(
        'Daily Rhythm occurrences require authenticated storage.',
      );
    }
    return 'chronospark.habit_occurrences.v1.$namespace';
  }

  @override
  Future<List<HabitOccurrenceEntity>> load() async {
    await _store.init();
    final String? raw = _store.load(persistenceKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <HabitOccurrenceEntity>[];
    }
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      throw const FormatException(
        'Daily Rhythm occurrence storage is not a list.',
      );
    }
    return decoded
        .map((dynamic value) {
          if (value is! Map<dynamic, dynamic>) {
            throw const FormatException(
              'Daily Rhythm occurrence entry is not an object.',
            );
          }
          return HabitOccurrenceEntity.fromJson(
            value.map<String, dynamic>(
              (dynamic key, dynamic item) => MapEntry(key.toString(), item),
            ),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> save(HabitOccurrenceEntity occurrence) {
    final Future<void> operation = _tail.then((_) async {
      final List<HabitOccurrenceEntity> current = await load();
      final int existing = current.indexWhere(
        (HabitOccurrenceEntity value) => value.id == occurrence.id,
      );
      final List<HabitOccurrenceEntity> next = current.toList(growable: true);
      if (existing >= 0) {
        next[existing] = occurrence;
      } else {
        next.add(occurrence);
      }
      next.sort(
        (HabitOccurrenceEntity left, HabitOccurrenceEntity right) =>
            left.recordedAt.compareTo(right.recordedAt),
      );
      await _store.save(
        persistenceKey,
        jsonEncode(
          next
              .map((HabitOccurrenceEntity value) => value.toJson())
              .toList(growable: false),
        ),
      );
    });
    _tail = operation.catchError((Object _) {});
    return operation;
  }

  @override
  Future<void> replaceSnapshot(List<HabitOccurrenceEntity> occurrences) {
    final List<HabitOccurrenceEntity> snapshot = List.unmodifiable(occurrences);
    final Future<void> operation = _tail.then((_) async {
      await _store.init();
      final Set<String> ids = <String>{};
      for (final HabitOccurrenceEntity occurrence in snapshot) {
        if (!ids.add(occurrence.id)) {
          throw StateError(
            'Daily Rhythm occurrence snapshot contains duplicate slots.',
          );
        }
      }
      final List<HabitOccurrenceEntity> sorted = snapshot.toList()
        ..sort(
          (HabitOccurrenceEntity left, HabitOccurrenceEntity right) =>
              left.recordedAt.compareTo(right.recordedAt),
        );
      await _store.save(
        persistenceKey,
        jsonEncode(
          sorted
              .map((HabitOccurrenceEntity value) => value.toJson())
              .toList(growable: false),
        ),
      );
    });
    _tail = operation.catchError((Object _) {});
    return operation;
  }
}
