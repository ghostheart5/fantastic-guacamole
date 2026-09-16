part of 'timeline_screen.dart';

DateTime _eventMoment(TimelineEventEntity event) {
  final moment = event.dueAt ?? event.timestamp;
  return event.dateOnly
      ? DateTime(moment.year, moment.month, moment.day)
      : moment.toLocal();
}

bool _isOpenDeadline(TimelineEventEntity event) {
  final bool hasDeadlineSemantics = switch (event.type) {
    TimelineEventType.deadline ||
    TimelineEventType.goal ||
    TimelineEventType.milestone => true,
    _ => false,
  };
  return hasDeadlineSemantics &&
      event.status != TimelineEventStatus.completed &&
      event.status != TimelineEventStatus.canceled &&
      event.status != TimelineEventStatus.skipped;
}

bool _inWindow({
  required DateTime moment,
  required DateTime now,
  required _TimelineWindow window,
}) {
  switch (window) {
    case _TimelineWindow.today:
      return moment.year == now.year &&
          moment.month == now.month &&
          moment.day == now.day;
    case _TimelineWindow.week:
      final DateTime start = DateTime(now.year, now.month, now.day);
      final DateTime end = DateTime(start.year, start.month, start.day + 7);
      return !moment.isBefore(start) && moment.isBefore(end);
    case _TimelineWindow.month:
      return moment.year == now.year && moment.month == now.month;
    case _TimelineWindow.year:
      return moment.year == now.year;
    case _TimelineWindow.all:
      return true;
  }
}

String _windowLabel(_TimelineWindow value) {
  return switch (value) {
    _TimelineWindow.today => 'Today',
    _TimelineWindow.week => 'Week',
    _TimelineWindow.month => 'Month',
    _TimelineWindow.year => 'Year',
    _TimelineWindow.all => 'All',
  };
}

String _filterLabel(_TimelineFilter value) {
  return switch (value) {
    _TimelineFilter.all => 'All',
    _TimelineFilter.overdue => 'Overdue',
    _TimelineFilter.upcoming => 'Upcoming',
    _TimelineFilter.milestones => 'Milestones',
    _TimelineFilter.risks => 'Risks',
    _TimelineFilter.recommendations => 'Recommendations',
  };
}

TimelineEventEntity? _nearestUpcoming(
  List<TimelineEventEntity> events,
  DateTime now,
) {
  final List<TimelineEventEntity> candidates =
      events
          .where((TimelineEventEntity event) {
            final DateTime? due = event.dueAt;
            return due != null &&
                _isOpenDeadline(event) &&
                due.isAfter(now) &&
                !event.isOverdue;
          })
          .toList(growable: false)
        ..sort(
          (a, b) => (a.dueAt ?? a.timestamp).compareTo(b.dueAt ?? b.timestamp),
        );
  return candidates.isEmpty ? null : candidates.first;
}
