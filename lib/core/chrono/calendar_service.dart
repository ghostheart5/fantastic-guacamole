import 'calendar_entry.dart';
import 'task.dart';
import 'time_block.dart';

class CalendarService {
  final Map<String, CalendarEntry> _entries = <String, CalendarEntry>{};

  CalendarEntry getDay(DateTime date) {
    final String key = _keyFor(date);
    return _entries[key] ?? CalendarEntry(date: _normalizedDate(date));
  }

  void addTimeBlock(DateTime date, TimeBlock block) {
    if (!block.start.isBefore(block.end)) {
      throw ArgumentError('TimeBlock start must be before end.');
    }

    final CalendarEntry entry = _ensureDay(date);
    final bool hasConflict = entry.timeBlocks.any(
      (TimeBlock existing) =>
          block.start.isBefore(existing.end) && block.end.isAfter(existing.start),
    );

    if (hasConflict) {
      throw StateError('TimeBlock overlaps with an existing block.');
    }

    final List<TimeBlock> updatedBlocks = <TimeBlock>[...entry.timeBlocks, block]
      ..sort((TimeBlock a, TimeBlock b) => a.start.compareTo(b.start));

    _entries[_keyFor(date)] = entry.copyWith(timeBlocks: updatedBlocks);
  }

  void addTask(DateTime date, Task task) {
    final CalendarEntry entry = _ensureDay(date);

    if (task.timeBlockId != null) {
      final bool linkedBlockExists = entry.timeBlocks.any(
        (TimeBlock block) => block.id == task.timeBlockId,
      );
      if (!linkedBlockExists) {
        throw StateError('Cannot link task to missing TimeBlock id: ${task.timeBlockId}');
      }
    }

    final List<Task> updatedTasks = <Task>[...entry.tasks, task];
    _entries[_keyFor(date)] = entry.copyWith(tasks: updatedTasks);
  }

  void completeTask(DateTime date, String taskId) {
    final CalendarEntry entry = _ensureDay(date);
    final int index = entry.tasks.indexWhere((Task task) => task.id == taskId);
    if (index == -1) {
      return;
    }

    final List<Task> updatedTasks = List<Task>.from(entry.tasks);
    updatedTasks[index] = updatedTasks[index].copyWith(completed: true);
    _entries[_keyFor(date)] = entry.copyWith(tasks: updatedTasks);
  }

  CalendarEntry _ensureDay(DateTime date) {
    final String key = _keyFor(date);
    return _entries.putIfAbsent(key, () => CalendarEntry(date: _normalizedDate(date)));
  }

  String _keyFor(DateTime date) {
    final DateTime normalized = _normalizedDate(date);
    final String month = normalized.month.toString().padLeft(2, '0');
    final String day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }

  DateTime _normalizedDate(DateTime date) => DateTime(date.year, date.month, date.day);
}
