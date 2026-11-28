import 'dart:convert';

import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/features/timeline/logic/task_calendar_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final generatedAt = DateTime.utc(2026, 11, 27, 12);

  test('exports the planned start in UTC with the saved duration', () {
    final task = TaskEntity(
      id: 'a',
      title: 'Timed task',
      scheduledFor: DateTime.parse('2026-11-28T10:05:00-06:00'),
      dueDate: DateTime.utc(2026, 11, 29),
      estimatedDuration: const Duration(minutes: 45),
    );
    final file = taskCalendarFile(task, generatedAt: generatedAt)!;
    expect(file, contains('DTSTART:20261128T160500Z\r\n'));
    expect(file, contains('DTEND:20261128T165000Z\r\n'));
    expect(file, contains('SUMMARY:Timed task\r\n'));
    expect(file, isNot(contains('VALUE=DATE')));
  });

  test('preserves the written date of an all-day deadline', () {
    final task = TaskEntity(
      id: 'b',
      title: 'Date-only task',
      dueDate: DateTime.utc(2026, 12, 31),
    );
    final file = taskCalendarFile(task, generatedAt: generatedAt)!;
    expect(file, contains('DTSTART;VALUE=DATE:20261231\r\n'));
    expect(file, contains('DTEND;VALUE=DATE:20270101\r\n'));
    expect(file, contains('TRANSP:TRANSPARENT\r\n'));
  });

  test('escapes task text and folds UTF-8 lines without leaking notes', () {
    final task = TaskEntity(
      id: 'c',
      title: 'Bring ${'🚀' * 24}; x, y\\z\r\nEND:VEVENT',
      description: 'PRIVATE NOTES',
      dueDate: DateTime(2026, 11, 28),
    );
    final file = taskCalendarFile(task, generatedAt: generatedAt)!;
    for (final line in file.split('\r\n')) {
      expect(utf8.encode(line).length, lessThanOrEqualTo(75));
    }
    final unfolded = file.replaceAll('\r\n ', '');
    expect(unfolded, contains('SUMMARY:Bring ${'🚀' * 24}'));
    expect(unfolded, contains(r'\; x\, y\\z\nEND:VEVENT'));
    expect(unfolded, isNot(contains('PRIVATE NOTES')));
    expect(
      unfolded.split('\r\n').where((line) => line == 'END:VEVENT'),
      hasLength(1),
    );
  });

  test('does not export a task without a date or a finished task', () {
    expect(
      taskCalendarFile(
        TaskEntity(id: 'd', title: 'No date'),
        generatedAt: generatedAt,
      ),
      isNull,
    );
    expect(
      taskCalendarFile(
        TaskEntity(
          id: 'e',
          title: 'Finished',
          isCompleted: true,
          dueDate: DateTime(2026, 11, 28),
        ),
        generatedAt: generatedAt,
      ),
      isNull,
    );
  });
}
