part of 'trajectory_engine_screen.dart';

typedef _ScheduleConflict = ({
  Task task,
  Task overlapping,
  DateTime suggestedStart,
});

bool _overlaps(DateTime start, DateTime end, Task other) {
  final otherStart = other.scheduledFor!;
  return start.isBefore(otherStart.add(other.estimatedDuration)) &&
      otherStart.isBefore(end);
}

_ScheduleConflict? _findScheduleConflict(List<Task> tasks, DateTime now) {
  final timed =
      tasks.where((task) => task.isActive && task.scheduledFor != null).toList()
        ..sort((a, b) {
          final order = a.scheduledFor!.compareTo(b.scheduledFor!);
          return order == 0 ? a.id.compareTo(b.id) : order;
        });
  for (var i = 1; i < timed.length; i++) {
    final task = timed[i];
    final start = task.scheduledFor!;
    if (!start.isAfter(now) ||
        task.recurrenceSeriesId != null ||
        task.recurrenceRule != RecurrenceRule.none) {
      continue;
    }
    final duration = task.estimatedDuration;
    final earlier = timed.take(i);
    final overlapping = earlier
        .where((other) => _overlaps(start, start.add(duration), other))
        .firstOrNull;
    if (overlapping == null) continue;

    var suggested = start;
    for (final other in timed) {
      if (other.id == task.id ||
          !_overlaps(suggested, suggested.add(duration), other)) {
        continue;
      }
      suggested = other.scheduledFor!.add(other.estimatedDuration);
    }
    final local = start.toLocal();
    final end = suggested.add(duration);
    final nextDay = DateTime(local.year, local.month, local.day + 1);
    if (suggested.isBefore(nextDay) &&
        !end.isAfter(nextDay) &&
        !_missesDeadline(task, end)) {
      return (task: task, overlapping: overlapping, suggestedStart: suggested);
    }
  }
  return null;
}

bool _missesDeadline(TaskEntity task, DateTime end) {
  final deadline = task.effectiveDueAt;
  return deadline != null && end.isAfter(deadline);
}

String _scheduleLabel(BuildContext context, DateTime date) {
  final strings = MaterialLocalizations.of(context);
  final local = date.toLocal();
  return '${strings.formatMediumDate(local)} · '
      '${strings.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
}

class _ScheduleConflictCard extends StatelessWidget {
  const _ScheduleConflictCard({required this.conflict, required this.onReview});

  final _ScheduleConflict conflict;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final task = conflict.task.title;
    final overlapping = conflict.overlapping.title;
    final current = _scheduleLabel(context, conflict.task.scheduledFor!);
    final proposed = _scheduleLabel(context, conflict.suggestedStart);

    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            journeyText(context, 'Schedule conflict', 'Conflicto de horario'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            journeyText(
              context,
              '$task ($current) overlaps $overlapping based on their estimated durations.',
              '$task ($current) se superpone con $overlapping según sus duraciones estimadas.',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            journeyText(
              context,
              'Suggested start for $task: $proposed.',
              'Inicio sugerido para $task: $proposed.',
            ),
          ),
          TextButton(
            onPressed: onReview,
            child: Text(
              journeyText(
                context,
                'Review schedule change',
                'Revisar cambio de horario',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension _ScheduleConflictReview on _TrajectoryEngineScreenState {
  Future<void> _reviewScheduleConflict(_ScheduleConflict displayed) async {
    if (_reviewingSchedule) return;
    _reviewingSchedule = true;
    try {
      await _openScheduleReview(displayed);
    } finally {
      _reviewingSchedule = false;
    }
  }

  Future<void> _openScheduleReview(_ScheduleConflict displayed) async {
    final generation = ref.read(authSessionBoundaryProvider).generation;
    final namespace = ref.read(accountStorageScopeProvider).v2Namespace;
    if (!_sameAccount(generation, namespace)) return;

    final tasks = await _readConflictTasks(generation, namespace);
    if (!mounted || tasks == null || !_sameAccount(generation, namespace)) {
      return;
    }
    final conflict = _findScheduleConflict(tasks, DateTime.now());
    if (conflict == null ||
        conflict.task.id != displayed.task.id ||
        conflict.overlapping.id != displayed.overlapping.id ||
        !conflict.suggestedStart.isAtSameMomentAs(displayed.suggestedStart) ||
        !_sameTaskDraftSource(conflict.task, displayed.task) ||
        !_sameTaskDraftSource(conflict.overlapping, displayed.overlapping)) {
      _scheduleChanged();
      return;
    }

    final task = conflict.task;
    final overlapping = conflict.overlapping.title;
    final proposed = _scheduleLabel(context, conflict.suggestedStart);
    final draft = await _dialogInThisAccount(
      generation,
      namespace,
      () => showTaskEditDialog(
        context: context,
        editable: task,
        goals: ref.read(goalsProvider),
        note: journeyText(
          context,
          'This task overlaps $overlapping. Review the suggested start ($proposed) before saving.',
          'Esta tarea se superpone con $overlapping. Revisa el inicio sugerido ($proposed) antes de guardar.',
        ),
        initialScheduledFor: conflict.suggestedStart.toLocal(),
        scheduleOnly: true,
      ),
    );
    if (draft == null || !_sameAccount(generation, namespace)) return;

    final currentTasks = await _readConflictTasks(generation, namespace);
    if (!mounted ||
        currentTasks == null ||
        !_sameAccount(generation, namespace)) {
      return;
    }
    final current = currentTasks
        .where((item) => item.id == task.id)
        .firstOrNull;
    if (current == null || !_sameTaskDraftSource(current, task)) {
      _scheduleChanged();
      return;
    }
    final start = draft.scheduledFor;
    final end = start?.add(task.estimatedDuration);
    if (start == null ||
        end == null ||
        !start.isAfter(DateTime.now()) ||
        _missesDeadline(task, end) ||
        currentTasks.any(
          (other) =>
              other.id != task.id &&
              other.scheduledFor != null &&
              _overlaps(start, end, other),
        )) {
      _showMessage(
        journeyText(
          context,
          'Choose a future time that fits before the deadline and avoids other scheduled tasks.',
          'Elige una hora futura que respete la fecha límite y no se superponga con otras tareas programadas.',
        ),
      );
      return;
    }
    await _saveReviewedTask(
      task,
      draft,
      generation,
      namespace,
      scheduleOnly: true,
    );
  }

  Future<List<Task>?> _readConflictTasks(
    int generation,
    String? namespace,
  ) async {
    try {
      return await ref.refresh(allTasksProvider.future);
    } catch (_) {
      if (_sameAccount(generation, namespace)) {
        _showMessage(
          journeyText(
            context,
            'Your tasks could not be read. Try again.',
            'No se pudieron leer tus tareas. Inténtalo de nuevo.',
          ),
        );
      }
      return null;
    }
  }

  void _scheduleChanged() => _showMessage(
    journeyText(
      context,
      'Your schedule changed. Review the latest suggestion.',
      'Tu horario cambió. Revisa la sugerencia actual.',
    ),
  );
}

bool _sameTaskDraftSource(Task a, Task b) =>
    (
      a.updatedAt,
      a.scheduledFor,
      a.dueDate,
      a.title,
      a.description,
      a.priority,
      a.estimatedDuration,
      a.goalId,
      a.recurrenceRule,
      a.recurrenceSeriesId,
    ) ==
    (
      b.updatedAt,
      b.scheduledFor,
      b.dueDate,
      b.title,
      b.description,
      b.priority,
      b.estimatedDuration,
      b.goalId,
      b.recurrenceRule,
      b.recurrenceSeriesId,
    );
