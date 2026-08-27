import 'package:fantastic_guacamole/domain/entities/calendar_entry.dart';
import 'package:fantastic_guacamole/domain/entities/calendar_entry_entity.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime start = DateTime.utc(2026, 7, 6, 9);
  final DateTime end = DateTime.utc(2026, 7, 6, 10);

  test('CalendarEntry is the canonical calendar entity', () {
    final CalendarEntry entry = CalendarEntry(
      id: 'entry-1',
      title: 'Deep work',
      description: 'the important block',
      start: start,
      end: end,
      taskId: 'task-1',
      isCompleted: true,
    );

    expect(entry, isA<CalendarEntryEntity>());
    expect(
      CalendarEntryEntity.fromJson(entry.toJson()).toJson(),
      entry.toJson(),
    );
  });

  test('TimeBlock is a lossless planner adapter over CalendarEntryEntity', () {
    final TimeBlock block = TimeBlock(
      id: 'block-1',
      taskId: 'task-1',
      title: 'Deep work',
      description: 'protected focus time',
      start: start,
      end: end,
      completed: true,
    );

    expect(block, isA<CalendarEntryEntity>());
    expect(block.description, 'protected focus time');
    expect(block.completed, block.isCompleted);
    expect(block.duration, const Duration(hours: 1));

    final TimeBlock updated = block.copyWith(completed: false);
    expect(updated.description, block.description);
    expect(updated.isCompleted, isFalse);
  });
}
