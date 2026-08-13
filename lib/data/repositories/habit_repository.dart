import 'dart:convert';

import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/sync/sync_mutation_dispatcher.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:flutter/foundation.dart';

@immutable
class HabitRecord {
  const HabitRecord({
    required this.id,
    required this.title,
    this.createdAt,
    this.updatedAt,
    this.userId,
    this.description,
    this.cadence = HabitCadence.daily,
    this.targetCount = 1,
    this.status = HabitStatus.active,
  });

  final String id;
  final String title;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? userId;
  final String? description;
  final HabitCadence cadence;
  final int targetCount;
  final HabitStatus status;

  bool get active => status == HabitStatus.active;

  HabitRecord copyWith({
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    String? description,
    HabitCadence? cadence,
    int? targetCount,
    HabitStatus? status,
  }) {
    return HabitRecord(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      description: description ?? this.description,
      cadence: cadence ?? this.cadence,
      targetCount: targetCount ?? this.targetCount,
      status: status ?? this.status,
    );
  }

  factory HabitRecord.fromEntity(HabitEntity entity) {
    return HabitRecord(
      id: entity.id,
      title: entity.title,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      userId: entity.userId,
      description: entity.description,
      cadence: entity.cadence,
      targetCount: entity.targetCount,
      status: entity.status,
    );
  }

  HabitEntity toEntity() {
    final DateTime? recordCreatedAt = createdAt;
    if (recordCreatedAt == null) {
      throw const FormatException(
        'Legacy habit record has no createdAt value and cannot become a HabitEntity.',
      );
    }
    return HabitEntity(
      id: id,
      title: title,
      createdAt: recordCreatedAt,
      updatedAt: updatedAt,
      userId: userId,
      description: description,
      cadence: cadence,
      targetCount: targetCount,
      status: status,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'userId': userId,
    'description': description,
    'cadence': cadence.name,
    'targetCount': targetCount,
    'status': status.name,
    'active': active,
  };

  factory HabitRecord.fromJson(Map<String, dynamic> json) {
    final String id = json['id']?.toString() ?? '';
    final String title = json['title']?.toString() ?? '';
    if (id.trim().isEmpty || title.trim().isEmpty) {
      throw const FormatException(
        'Habit record requires a non-empty id and title.',
      );
    }
    final DateTime? createdAt = _parseOptionalDate(json['createdAt']);
    final DateTime? updatedAt = _parseOptionalDate(json['updatedAt']);
    return HabitRecord(
      id: id,
      title: title,
      createdAt: createdAt,
      updatedAt: updatedAt,
      userId: json['userId']?.toString(),
      description: json['description']?.toString(),
      cadence: HabitCadence.values.firstWhere(
        (HabitCadence value) => value.name == json['cadence']?.toString(),
        orElse: () => HabitCadence.daily,
      ),
      targetCount: ((json['targetCount'] as num?)?.toInt() ?? 1).clamp(1, 365),
      status: HabitStatus.values.firstWhere(
        (HabitStatus value) => value.name == json['status']?.toString(),
        orElse: () =>
            json['active'] == false ? HabitStatus.paused : HabitStatus.active,
      ),
    );
  }

  static DateTime? _parseOptionalDate(Object? value) {
    if (value == null) return null;
    final DateTime? parsed = DateTime.tryParse(value.toString());
    if (parsed == null) {
      throw FormatException('Invalid habit timestamp: $value');
    }
    return parsed;
  }
}

class HabitRepository {
  HabitRepository(HiveStorage<String> storage, {this._syncDispatcher})
    : _storage = storage;

  HabitRepository.unavailable({this._syncDispatcher}) : _storage = null;

  static const String _key = 'habit_records_v1';

  final HiveStorage<String>? _storage;
  final SyncMutationDispatcher? _syncDispatcher;
  bool _cancelled = false;
  Future<void> _writeQueue = Future<void>.value();

  Future<void> cancelAndDrain() async {
    _cancelled = true;
    await _writeQueue.catchError((Object _) {});
  }

  void dispose() {
    _cancelled = true;
  }

  Future<List<HabitRecord>> getHabits() async {
    final HiveStorage<String> storage = _requireStorage();
    await storage.open();
    final String? raw = storage.get(_key);
    if (raw == null || raw.trim().isEmpty) {
      return const <HabitRecord>[];
    }
    final Object? decoded = jsonDecode(raw);
    final List<dynamic> list = decoded is List<dynamic>
        ? decoded
        : const <dynamic>[];
    return list
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> map) => HabitRecord.fromJson(
            map.map<String, dynamic>(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .where((HabitRecord record) => record.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> saveHabits(List<HabitRecord> habits) =>
      _serializeWrite(() async {
        final List<HabitRecord> previous = await getHabits();
        await _requireStorage().put(
          _key,
          jsonEncode(
            habits
                .map((HabitRecord item) => item.toJson())
                .toList(growable: false),
          ),
        );

        final Set<String> nextIds = habits
            .map((HabitRecord item) => item.id)
            .where((String id) => id.isNotEmpty)
            .toSet();
        final Set<String> removedIds = previous
            .map((HabitRecord item) => item.id)
            .where((String id) => id.isNotEmpty && !nextIds.contains(id))
            .toSet();

        for (final HabitRecord habit in habits) {
          await _syncDispatcher?.enqueueUpsert(
            tableName: 'habits',
            recordId: habit.id,
            payload: <String, dynamic>{
              'id': habit.id,
              'title': habit.title,
              'created_at': habit.createdAt?.toUtc().toIso8601String(),
              'user_id': habit.userId,
              'description': habit.description,
              'cadence': habit.cadence.name,
              'target_count': habit.targetCount,
              'status': habit.status.name,
              'active': habit.active,
              'updated_at': (habit.updatedAt ?? DateTime.now())
                  .toUtc()
                  .toIso8601String(),
              'deleted_at': null,
            },
          );
        }

        for (final String removedId in removedIds) {
          await _syncDispatcher?.enqueueDelete(
            tableName: 'habits',
            recordId: removedId,
          );
        }
      });

  Future<void> _serializeWrite(Future<void> Function() action) {
    if (_cancelled) {
      return Future<void>.error(
        StateError('Habit mutation canceled during account transition.'),
      );
    }
    final Future<void> next = _writeQueue.then((_) => action());
    _writeQueue = next.catchError((Object _) {});
    return next;
  }

  HiveStorage<String> _requireStorage() {
    final HiveStorage<String>? storage = _storage;
    if (storage == null) {
      throw StateError(
        'Habit storage is unavailable while the account transition is unsafe.',
      );
    }
    return storage;
  }
}
