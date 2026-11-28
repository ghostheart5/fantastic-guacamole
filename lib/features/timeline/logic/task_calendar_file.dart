import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';

/// An importable calendar snapshot of one saved task. A planned work time
/// takes precedence over its deadline. Date-only deadlines float by date.
String? taskCalendarFile(TaskEntity task, {required DateTime generatedAt}) {
  final scheduled = task.scheduledFor;
  final start = scheduled ?? task.dueDate;
  if (!task.isActive || start == null) return null;

  final allDay = scheduled == null && task.hasDateOnlyDeadline;
  final duration = task.estimatedDuration ?? const Duration(minutes: 30);
  final end = allDay
      ? DateTime.utc(start.year, start.month, start.day + 1)
      : start.add(
          duration > Duration.zero ? duration : const Duration(minutes: 30),
        );
  final uid = sha256.convert(utf8.encode(task.id)).toString();
  return [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Axiomara//Task Calendar Export//EN',
    'BEGIN:VEVENT',
    'UID:$uid@axiomara',
    'DTSTAMP:${_utcStamp(generatedAt)}',
    if (allDay) ...[
      'DTSTART;VALUE=DATE:${_calendarDate(start)}',
      'DTEND;VALUE=DATE:${_calendarDate(end)}',
      'TRANSP:TRANSPARENT',
    ] else ...[
      'DTSTART:${_utcStamp(start)}',
      'DTEND:${_utcStamp(end)}',
    ],
    'SUMMARY:${_escapeCalendarText(task.title)}',
    'END:VEVENT',
    'END:VCALENDAR',
    '',
  ].map(_foldCalendarLine).join('\r\n');
}

String _calendarDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}${_two(date.month)}${_two(date.day)}';

String _two(int value) => value.toString().padLeft(2, '0');

String _utcStamp(DateTime date) {
  final utc = date.toUtc();
  return '${_calendarDate(utc)}T${_two(utc.hour)}${_two(utc.minute)}${_two(utc.second)}Z';
}

String _escapeCalendarText(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll(RegExp(r'\r\n|\r|\n'), r'\n')
    .replaceAll(RegExp(r'[\x00-\x08\x0b-\x1f\x7f]'), '')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,');

String _foldCalendarLine(String line) {
  final folded = StringBuffer();
  var bytes = 0;
  for (final rune in line.runes) {
    final character = String.fromCharCode(rune);
    final width = utf8.encode(character).length;
    if (bytes + width > 75) {
      folded.write('\r\n ');
      bytes = 1;
    }
    folded.write(character);
    bytes += width;
  }
  return folded.toString();
}
