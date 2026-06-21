import 'task.dart';
import 'time_block.dart';

class CalendarEntry {
  const CalendarEntry({
    required this.date,
    this.timeBlocks = const <TimeBlock>[],
    this.tasks = const <Task>[],
  });

  final DateTime date;
  final List<TimeBlock> timeBlocks;
  final List<Task> tasks;

  CalendarEntry copyWith({DateTime? date, List<TimeBlock>? timeBlocks, List<Task>? tasks}) {
    return CalendarEntry(
      date: date ?? this.date,
      timeBlocks: timeBlocks ?? this.timeBlocks,
      tasks: tasks ?? this.tasks,
    );
  }
}
