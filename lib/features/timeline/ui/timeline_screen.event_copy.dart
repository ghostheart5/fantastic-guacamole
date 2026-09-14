part of 'timeline_screen.dart';

extension _TimelineEventCopy on _TimelineEventTile {
  // Translate the generated wrapper only. A user can give a task or reflection
  // the same title, so require the task-completion provenance and detail shape.
  bool get _isTaskCompleted =>
      event.id.startsWith('timeline-task-complete-') &&
      event.sourceFeature == 'task' &&
      event.type == TimelineEventType.reflection &&
      event.title == 'Task Completed' &&
      event.detail.endsWith(' marked complete.');

  String _localizedTitle(BuildContext context) => _isTaskCompleted
      ? journeyText(context, 'Task Completed', 'Tarea completada')
      : _displayTitle;

  String _localizedDetail(BuildContext context) {
    if (_isTaskCompleted) {
      final taskTitle = event.detail.substring(
        0,
        event.detail.length - ' marked complete.'.length,
      );
      return journeyText(
        context,
        event.detail,
        '$taskTitle marcada como completada.',
      );
    }
    if (_isTaskAdded) {
      return journeyText(
        context,
        'Added to your trajectory',
        'Añadida a tu trayectoria',
      );
    }
    return event.id.startsWith('timeline-projected-')
        ? journeyLabel(context, event.detail)
        : event.detail;
  }
}
