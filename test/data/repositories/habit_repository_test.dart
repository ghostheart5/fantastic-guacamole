import 'package:fantastic_guacamole/data/repositories/habit_repository.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HabitRecord serialization', () {
    test('round-trips every HabitEntity field through JSON', () {
      final HabitEntity original = HabitEntity(
        id: 'habit-1',
        title: 'Morning review',
        createdAt: DateTime.utc(2026, 8, 4, 8),
        updatedAt: DateTime.utc(2026, 8, 4, 9),
        userId: 'user-1',
        description: 'Review daily priorities',
        cadence: HabitCadence.weekly,
        targetCount: 3,
        status: HabitStatus.archived,
      );

      final HabitRecord restored = HabitRecord.fromJson(
        HabitRecord.fromEntity(original).toJson(),
      );
      final HabitEntity roundTripped = restored.toEntity();

      expect(roundTripped.id, original.id);
      expect(roundTripped.title, original.title);
      expect(roundTripped.createdAt, original.createdAt);
      expect(roundTripped.updatedAt, original.updatedAt);
      expect(roundTripped.userId, original.userId);
      expect(roundTripped.description, original.description);
      expect(roundTripped.cadence, original.cadence);
      expect(roundTripped.targetCount, original.targetCount);
      expect(roundTripped.status, HabitStatus.archived);
      expect(restored.active, isFalse);
    });

    test('rejects malformed habit payloads', () {
      expect(
        () => HabitRecord.fromJson(<String, dynamic>{
          'id': 'habit-1',
          'title': 'Morning review',
          'createdAt': 'not-a-date',
        }),
        throwsFormatException,
      );
      expect(
        () => HabitRecord.fromJson(<String, dynamic>{'title': 'Missing id'}),
        throwsFormatException,
      );
    });
  });
}
