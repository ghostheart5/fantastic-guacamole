import 'dart:convert';

import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';

enum HabitOccurrenceMutation { inserted, idempotent, conflict, exhausted }

class HabitOccurrenceRepository {
  HabitOccurrenceRepository(HiveStorage<String> storage) : _storage = storage;
  HabitOccurrenceRepository.unavailable() : _storage = null;

  static const String persistenceKey = 'habit_occurrences_v2';
  final HiveStorage<String>? _storage;
  bool _cancelled = false;
  Future<void> _writeQueue = Future<void>.value();

  Future<void> cancelAndDrain() async {
    _cancelled = true;
    await _writeQueue.catchError((Object _) {});
  }

  void dispose() => _cancelled = true;

  Future<HabitOccurrence?> getOccurrence(
    String habitId,
    String periodKey,
    int ordinal,
  ) async {
    return (await _read()).cast<HabitOccurrence?>().firstWhere(
      (HabitOccurrence? item) =>
          item?.habitId == habitId &&
          item?.periodKey == periodKey &&
          item?.ordinal == ordinal,
      orElse: () => null,
    );
  }

  Future<List<HabitOccurrence>> listOccurrencesForHabit(String habitId) async =>
      (await _read())
          .where((HabitOccurrence item) => item.habitId == habitId)
          .toList(growable: false);

  Future<List<HabitOccurrence>> listOccurrencesForPeriod(
    String habitId,
    String periodKey,
  ) async => (await listOccurrencesForHabit(habitId))
      .where((HabitOccurrence item) => item.periodKey == periodKey)
      .toList(growable: false);

  Future<HabitOccurrenceMutation> completeOccurrence({
    required String habitId,
    required String periodKey,
    required int ordinal,
    required int targetCount,
    DateTime? at,
  }) => _mutate(
    habitId: habitId,
    periodKey: periodKey,
    ordinal: ordinal,
    targetCount: targetCount,
    status: HabitOccurrenceStatus.completed,
    at: at ?? DateTime.now(),
  );

  Future<HabitOccurrenceMutation> skipOccurrence({
    required String habitId,
    required String periodKey,
    required int ordinal,
    required int targetCount,
    DateTime? at,
  }) => _mutate(
    habitId: habitId,
    periodKey: periodKey,
    ordinal: ordinal,
    targetCount: targetCount,
    status: HabitOccurrenceStatus.skipped,
    at: at ?? DateTime.now(),
  );

  Future<HabitOccurrenceMutation> _mutate({
    required String habitId,
    required String periodKey,
    required int ordinal,
    required int targetCount,
    required HabitOccurrenceStatus status,
    required DateTime at,
  }) async {
    if (ordinal < 1 || ordinal > targetCount.clamp(1, 365)) {
      return HabitOccurrenceMutation.exhausted;
    }
    HabitOccurrenceMutation result = HabitOccurrenceMutation.exhausted;
    await _serializeWrite(() async {
      final List<HabitOccurrence> all = await _read();
      final int index = all.indexWhere(
        (HabitOccurrence item) =>
            item.habitId == habitId &&
            item.periodKey == periodKey &&
            item.ordinal == ordinal,
      );
      if (index >= 0) {
        result = all[index].status == status
            ? HabitOccurrenceMutation.idempotent
            : HabitOccurrenceMutation.conflict;
        return;
      }
      all.add(
        HabitOccurrence(
          habitId: habitId,
          periodKey: periodKey,
          ordinal: ordinal,
          status: status,
          completedAt: status == HabitOccurrenceStatus.completed ? at : null,
          skippedAt: status == HabitOccurrenceStatus.skipped ? at : null,
        ),
      );
      await _write(all);
      result = HabitOccurrenceMutation.inserted;
    });
    return result;
  }

  Future<List<HabitOccurrence>> _read() async {
    final HiveStorage<String> storage = _requireStorage();
    await storage.open();
    final String? raw = storage.get(persistenceKey);
    if (raw == null || raw.trim().isEmpty) return <HabitOccurrence>[];
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) return <HabitOccurrence>[];
    return decoded
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> item) => HabitOccurrence.fromJson(
            item.map<String, dynamic>(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .toList(growable: true);
  }

  Future<void> _write(List<HabitOccurrence> values) => _requireStorage().put(
    persistenceKey,
    jsonEncode(
      values
          .map((HabitOccurrence item) => item.toJson())
          .toList(growable: false),
    ),
  );

  Future<void> _serializeWrite(Future<void> Function() action) {
    if (_cancelled) {
      return Future<void>.error(
        StateError(
          'Habit occurrence mutation canceled during account transition.',
        ),
      );
    }
    final Future<void> next = _writeQueue.then((_) => action());
    _writeQueue = next.catchError((Object _) {});
    return next;
  }

  HiveStorage<String> _requireStorage() =>
      _storage ??
      (throw StateError(
        'Habit occurrence storage is unavailable while the account transition is unsafe.',
      ));
}
