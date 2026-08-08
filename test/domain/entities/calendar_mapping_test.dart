import 'package:fantastic_guacamole/domain/entities/calendar_entry.dart';
import 'package:fantastic_guacamole/domain/entities/calendar_entry_entity.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:flutter_test/flutter_test.dart';

/// Characterisation tests for the `CalendarEntry` / `CalendarEntryEntity` /
/// `TimeBlock` triplication. See the TODOs on those three files.
///
/// All three describe the same concept with the same six fields. These tests
/// pin that equivalence down so a field added to one type without the others
/// fails here instead of silently going missing at a layer boundary.

CalendarEntryEntity entityFromEngineEntry(CalendarEntry entry) {
  return CalendarEntryEntity(
    id: entry.id,
    title: entry.title,
    description: entry.description,
    start: entry.start,
    end: entry.end,
    taskId: entry.taskId,
    isCompleted: entry.isCompleted,
  );
}

CalendarEntry engineEntryFromEntity(CalendarEntryEntity entity) {
  return CalendarEntry(
    id: entity.id,
    title: entity.title,
    description: entity.description,
    start: entity.start,
    end: entity.end,
    taskId: entity.taskId,
    isCompleted: entity.isCompleted,
  );
}

CalendarEntryEntity entityFromTimeBlock(TimeBlock block) {
  return CalendarEntryEntity(
    id: block.id,
    title: block.title,
    start: block.start,
    end: block.end,
    taskId: block.taskId,
    isCompleted: block.completed,
  );
}

void main() {
  final DateTime start = DateTime.utc(2026, 7, 6, 9);
  final DateTime end = DateTime.utc(2026, 7, 6, 10);

  group('CalendarEntry <-> CalendarEntryEntity', () {
    test('a full round trip preserves every field', () {
      final CalendarEntry original = CalendarEntry(
        id: 'entry-1',
        title: 'Deep work',
        description: 'the important block',
        start: start,
        end: end,
        taskId: 'task-1',
        isCompleted: true,
      );

      final CalendarEntry restored = engineEntryFromEntity(
        entityFromEngineEntry(original),
      );

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.description, original.description);
      expect(restored.start, original.start);
      expect(restored.end, original.end);
      expect(restored.taskId, original.taskId);
      expect(restored.isCompleted, original.isCompleted);
    });

    test('null optionals survive the round trip as null', () {
      final CalendarEntry original = CalendarEntry(
        id: 'entry-2',
        title: 'No task link',
        start: start,
        end: end,
      );

      final CalendarEntry restored = engineEntryFromEntity(
        entityFromEngineEntry(original),
      );

      expect(restored.description, isNull);
      expect(restored.taskId, isNull);
      expect(restored.isCompleted, isFalse);
    });

    test('both types compute duration identically', () {
      final CalendarEntry entry = CalendarEntry(
        id: 'entry-3',
        title: 'Block',
        start: start,
        end: end,
      );

      expect(entry.duration, entityFromEngineEntry(entry).duration);
      expect(entry.duration, const Duration(hours: 1));
    });
  });

  group('TimeBlock -> CalendarEntryEntity', () {
    test('maps completed onto isCompleted without loss', () {
      final TimeBlock block = TimeBlock(
        id: 'block-1',
        taskId: 'task-1',
        title: 'Deep work',
        start: start,
        end: end,
        completed: true,
      );

      final CalendarEntryEntity entity = entityFromTimeBlock(block);

      expect(entity.id, block.id);
      expect(entity.taskId, block.taskId);
      expect(entity.title, block.title);
      expect(entity.start, block.start);
      expect(entity.end, block.end);
      expect(
        entity.isCompleted,
        block.completed,
        reason: 'completed and isCompleted are the same field under two names',
      );
    });

    test(
      'TimeBlock has no description field, so that data cannot survive',
      () {
        final CalendarEntryEntity withDescription = CalendarEntryEntity(
          id: 'entry-4',
          title: 'Has a description',
          description: 'this is lost when converted to TimeBlock',
          start: start,
          end: end,
        );

        final TimeBlock block = TimeBlock(
          id: withDescription.id,
          taskId: withDescription.taskId ?? '',
          title: withDescription.title,
          start: withDescription.start,
          end: withDescription.end,
          completed: withDescription.isCompleted,
        );

        expect(entityFromTimeBlock(block).description, isNull);
      },
    );
  });
}
