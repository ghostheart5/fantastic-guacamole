import 'package:fantastic_guacamole/domain/entities/calendar_entry_entity.dart';

/// Planner compatibility view over [CalendarEntryEntity].
///
/// The historical `completed` name remains available, but the block stores no
/// state beyond the canonical calendar entity.
@Deprecated('Use CalendarEntryEntity.')
class TimeBlock extends CalendarEntryEntity {
  const TimeBlock({
    required super.id,
    required String taskId,
    required super.title,
    required super.start,
    required super.end,
    bool completed = false,
    super.description,
  }) : super(taskId: taskId, isCompleted: completed);

  @override
  String get taskId => super.taskId!;

  @override
  TimeBlock copyWith({
    String? id,
    String? taskId,
    String? title,
    String? description,
    DateTime? start,
    DateTime? end,
    bool? isCompleted,
    bool? completed,
  }) {
    return TimeBlock(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      description: description ?? this.description,
      start: start ?? this.start,
      end: end ?? this.end,
      completed: completed ?? isCompleted ?? this.completed,
    );
  }
}
