part of 'si_one_tap_engine.dart';

extension _TodayQuestions on _Run {
  // ------------------------------------------------------------- Plan my day

  SIOneTapAnswer planMyDay() {
    if (isEmptyAccount) return empty('plan today', 'planear hoy');
    final List<SIV2TaskEvidence> overdue = tasks.where(isOverdue).toList()
      ..sort(compareTasks);
    final List<SIV2TaskEvidence> dueToday = tasks.where((
      SIV2TaskEvidence task,
    ) {
      if (isOverdue(task)) return false;
      final DateTime? day = taskDay(task);
      return day != null && !day.isAfter(today);
    }).toList()..sort(compareTasks);
    final List<SIV2TaskEvidence> undated =
        tasks.where((SIV2TaskEvidence task) => taskDay(task) == null).toList()
          ..sort(compareTasks);
    final List<SIV2HabitEvidence> habitsToCheck = snapshot.habits
        .where(
          (SIV2HabitEvidence h) =>
              h.cadence == HabitCadence.daily && !h.checkedInThisPeriod,
        )
        .toList(growable: false);
    final List<SIV2TaskEvidence> ordered = <SIV2TaskEvidence>[
      ...overdue,
      ...dueToday,
    ];

    fact(
      t(
        '${overdue.length} open ${overdue.length == 1 ? 'task is' : 'tasks are'} overdue and ${dueToday.length} ${dueToday.length == 1 ? 'is' : 'are'} due or planned for today.',
        '${overdue.length} ${overdue.length == 1 ? 'tarea abierta está vencida' : 'tareas abiertas están vencidas'} y ${dueToday.length} ${dueToday.length == 1 ? 'es' : 'son'} para hoy.',
      ),
      <String>[tasksGroup],
    );
    for (final SIV2TaskEvidence task in ordered.take(5)) {
      fact(
        '"${task.title}" · ${timing(task)} · ${t('priority', 'prioridad')} ${task.priority}/5',
        <String>[taskId(task)],
      );
    }
    if (habitsToCheck.isNotEmpty) {
      fact(
        t(
          '${count(habitsToCheck.length, 'daily habit has', 'daily habits have', 'hábito diario no tiene', 'hábitos diarios no tienen')} no check-in yet today.',
          '${count(habitsToCheck.length, 'hábito diario no tiene', 'hábitos diarios no tienen', 'hábito diario no tiene', 'hábitos diarios no tienen')} registro hoy todavía.',
        ),
        <String>[habitsGroup],
      );
    }
    infer(
      t(
        'The order is overdue first, then higher priority, then the earlier day.',
        'El orden es: primero lo vencido, luego la mayor prioridad y luego el día más cercano.',
      ),
    );
    missing(
      t(
        'How much time you have today is not recorded, so this is an order, not a schedule.',
        'No se registra cuánto tiempo tienes hoy, así que esto es un orden, no un horario.',
      ),
    );
    if (undated.isNotEmpty) {
      missing(
        t(
          '${count(undated.length, 'open task has', 'open tasks have', 'tarea abierta no tiene', 'tareas abiertas no tienen')} no date, so ${undated.length == 1 ? 'it is' : 'they are'} not placed in today\'s order.',
          '${count(undated.length, 'tarea abierta no tiene', 'tareas abiertas no tienen', 'tarea abierta no tiene', 'tareas abiertas no tienen')} fecha, así que no ${undated.length == 1 ? 'entra' : 'entran'} en el orden de hoy.',
        ),
      );
    }

    if (ordered.isEmpty) {
      final String start = undated.isNotEmpty
          ? t(
              'Nothing is overdue or due today. You have ${count(undated.length, 'open task', 'open tasks', 'tarea abierta', 'tareas abiertas')} with no date.',
              'No hay nada vencido ni para hoy. Tienes ${count(undated.length, 'tarea abierta', 'tareas abiertas', 'tarea abierta', 'tareas abiertas')} sin fecha.',
            )
          : t(
              'No task is overdue or due today.',
              'Ninguna tarea está vencida ni es para hoy.',
            );
      return finish(
        direct: start,
        recommendation: undated.isNotEmpty
            ? t(
                'If you want to move something forward, "${undated.first.title}" is your highest-priority task without a date.',
                'Si quieres avanzar en algo, "${undated.first.title}" es tu tarea de mayor prioridad sin fecha.',
              )
            : habitsToCheck.isNotEmpty
            ? t(
                'Check in with your daily habits, or save a task in Add something if something needs a place.',
                'Registra tus hábitos diarios, o guarda una tarea en Añadir algo si algo necesita un lugar.',
              )
            : t(
                'Your day is open. Save a task in Add something if something needs a place.',
                'Tu día está libre. Guarda una tarea en Añadir algo si algo necesita un lugar.',
              ),
        offerAdd: undated.isEmpty,
      );
    }
    final SIV2TaskEvidence first = ordered.first;
    final String then = ordered.length > 1
        ? t(
            ' Then "${ordered[1].title}"${ordered.length > 2 ? ', then "${ordered[2].title}"' : ''}.',
            ' Después "${ordered[1].title}"${ordered.length > 2 ? ', luego "${ordered[2].title}"' : ''}.',
          )
        : '';
    return finish(
      direct: t(
        '${count(ordered.length, 'task needs', 'tasks need', 'tarea necesita', 'tareas necesitan')} you today: ${overdue.length} overdue and ${dueToday.length} due or planned for today.',
        '${count(ordered.length, 'tarea necesita', 'tareas necesitan', 'tarea necesita', 'tareas necesitan')} de ti hoy: ${overdue.length} vencida${overdue.length == 1 ? '' : 's'} y ${dueToday.length} para hoy.',
      ),
      recommendation: t(
        'Start with "${first.title}" (${timing(first)}).$then Nothing was changed.',
        'Empieza con "${first.title}" (${timing(first)}).$then No se cambió nada.',
      ),
    );
  }

  // -------------------------------------------------------- What's coming up

  SIOneTapAnswer whatsComingUp() {
    if (isEmptyAccount) {
      return empty('show as coming up', 'mostrar como próximo');
    }
    final DateTime end = today.add(const Duration(days: 8));
    bool inRange(DateTime day) => !day.isBefore(today) && day.isBefore(end);
    final Set<String> taskIds = tasks.map((SIV2TaskEvidence t) => t.id).toSet();
    final List<({DateTime day, String text, String id})> items =
        <({DateTime day, String text, String id})>[];
    for (final SIV2TaskEvidence task in tasks) {
      if (isOverdue(task)) continue;
      final DateTime? day = taskDay(task);
      if (day != null && inRange(day)) {
        items.add((
          day: day,
          text: '"${task.title}" · ${timing(task)}',
          id: taskId(task),
        ));
      }
    }
    for (final SIV2TimelineEvidence event in snapshot.timeline) {
      final DateTime? due = event.dueAt;
      if (due == null ||
          (event.relatedId != null && taskIds.contains(event.relatedId)) ||
          const <String>{
            'completed',
            'skipped',
            'canceled',
          }.contains(event.status)) {
        continue;
      }
      final DateTime day = dayOf(due);
      if (inRange(day) && !due.toLocal().isBefore(now)) {
        items.add((
          day: day,
          text: '"${event.title}" · ${dateLabel(day)}',
          id: timelineLink(event),
        ));
      }
    }
    for (final SIV2GoalEvidence goal in snapshot.goals) {
      final DateTime? target = goal.targetDate;
      if (target == null) continue;
      final DateTime day = goalDay(goal)!;
      if (inRange(day)) {
        items.add((
          day: day,
          text: t(
            'Goal "${goal.title}" · target ${dateLabel(day)}',
            'Meta "${goal.title}" · fecha objetivo ${dateLabel(day)}',
          ),
          id: goalLink(goal),
        ));
      }
    }
    items.sort((a, b) {
      final int byDay = a.day.compareTo(b.day);
      return byDay != 0 ? byDay : a.text.compareTo(b.text);
    });
    final int undated = tasks
        .where((SIV2TaskEvidence task) => taskDay(task) == null)
        .length;
    final int overdueCount = tasks.where(isOverdue).length;

    if (items.isEmpty) {
      missing(
        t(
          'Only items with a saved date or time can appear here.',
          'Solo pueden aparecer elementos con fecha u hora guardadas.',
        ),
      );
      if (undated > 0) {
        missing(
          t(
            '${count(undated, 'open task has', 'open tasks have', 'tarea abierta no tiene', 'tareas abiertas no tienen')} no date.',
            '${count(undated, 'tarea abierta no tiene', 'tareas abiertas no tienen', 'tarea abierta no tiene', 'tareas abiertas no tienen')} fecha.',
          ),
        );
      }
      if (overdueCount > 0) {
        fact(
          t(
            '${count(overdueCount, 'open task is', 'open tasks are', 'tarea abierta está', 'tareas abiertas están')} already overdue.',
            '${count(overdueCount, 'tarea abierta ya está', 'tareas abiertas ya están', 'tarea abierta ya está', 'tareas abiertas ya están')} vencida${overdueCount == 1 ? '' : 's'}.',
          ),
          <String>[tasksGroup],
        );
      }
      return finish(
        direct: t(
          'Nothing with a date is coming up in the next 7 days.',
          'No viene nada con fecha en los próximos 7 días.',
        ),
        recommendation: overdueCount > 0
            ? t(
                'Your open week is a good time to look at what is already overdue. Ask "What am I falling behind on".',
                'Tu semana libre es buen momento para mirar lo que ya venció. Pregunta "Qué estoy dejando atrás".',
              )
            : t(
                'Your week is open. Save something in Add something if a date should be on it.',
                'Tu semana está libre. Guarda algo en Añadir algo si debe haber una fecha.',
              ),
        offerAdd: undated == 0,
      );
    }
    fact(
      t(
        '${count(items.length, 'item has', 'items have', 'elemento tiene', 'elementos tienen')} a date in the next 7 days.',
        '${count(items.length, 'elemento tiene', 'elementos tienen', 'elemento tiene', 'elementos tienen')} fecha en los próximos 7 días.',
      ),
      <String>[items.first.id],
    );
    for (final item in items.take(6)) {
      fact(item.text, <String>[item.id]);
    }
    if (items.length > 6) {
      missing(
        t(
          '${items.length - 6} more are not listed here.',
          'Hay ${items.length - 6} más que no se muestran aquí.',
        ),
      );
    }
    if (undated > 0) {
      missing(
        t(
          '${count(undated, 'open task has', 'open tasks have', 'tarea abierta no tiene', 'tareas abiertas no tienen')} no date and is not shown.',
          '${count(undated, 'tarea abierta no tiene', 'tareas abiertas no tienen', 'tarea abierta no tiene', 'tareas abiertas no tienen')} fecha y no se muestra.',
        ),
      );
    }
    final item = items.first;
    return finish(
      direct: t(
        '${count(items.length, 'item is', 'items are', 'elemento está', 'elementos están')} coming up in the next 7 days. The nearest is ${item.text}.',
        '${count(items.length, 'elemento viene', 'elementos vienen', 'elemento viene', 'elementos vienen')} en los próximos 7 días. Lo más cercano es ${item.text}.',
      ),
      recommendation: t(
        'Look at ${item.text} first. Nothing was changed.',
        'Mira primero ${item.text}. No se cambió nada.',
      ),
    );
  }

  // ------------------------------------------------ Falling behind / on track

  List<SIV2TaskEvidence> get overdueByWait =>
      tasks.where(isOverdue).toList()..sort(compareByWait);

  /// A habit counts as quiet only when it is old enough to judge and has no
  /// check-in in the whole 14 day window.
  List<SIV2HabitEvidence> get quietHabits => snapshot.habits
      .where(
        (SIV2HabitEvidence h) =>
            h.cadence != HabitCadence.monthly &&
            h.checkInsInWindow == 0 &&
            now.difference(h.trackedSince.toLocal()).inDays >= _habitWindowDays,
      )
      .toList(growable: false);

  List<SIV2GoalEvidence> get lateGoals => snapshot.goals
      .where((SIV2GoalEvidence g) => goalIsLate(g))
      .toList(growable: false);

  List<SIV2MilestoneEvidence> get lateMilestones => snapshot.milestones
      .where(
        (SIV2MilestoneEvidence m) =>
            !m.archived &&
            !m.completed &&
            m.targetDate != null &&
            deadlinePast(m.targetDate!, m.targetDay),
      )
      .toList(growable: false);

  void _behindFacts(
    List<SIV2TaskEvidence> overdue,
    List<SIV2GoalEvidence> goals,
    List<SIV2MilestoneEvidence> milestones,
    List<SIV2HabitEvidence> habits,
  ) {
    if (overdue.isNotEmpty) {
      fact(
        t(
          '${count(overdue.length, 'open task is', 'open tasks are', 'tarea abierta está', 'tareas abiertas están')} overdue.',
          '${count(overdue.length, 'tarea abierta está', 'tareas abiertas están', 'tarea abierta está', 'tareas abiertas están')} vencida${overdue.length == 1 ? '' : 's'}.',
        ),
        <String>[tasksGroup],
      );
      for (final SIV2TaskEvidence task in overdue.take(4)) {
        fact('"${task.title}" · ${timing(task)}', <String>[taskId(task)]);
      }
    }
    for (final SIV2GoalEvidence goal in goals.take(3)) {
      fact(
        t(
          'Goal "${goal.title}" passed its target date (${dateLabel(goalDay(goal)!)}) and is still active.',
          'La meta "${goal.title}" pasó su fecha objetivo (${dateLabel(goalDay(goal)!)}) y sigue activa.',
        ),
        <String>[goalLink(goal)],
      );
    }
    for (final SIV2MilestoneEvidence item in milestones.take(3)) {
      fact(
        t(
          'Milestone "${item.title}" passed its target date (${dateLabel(milestoneDay(item)!)}) and is not done.',
          'El hito "${item.title}" pasó su fecha objetivo (${dateLabel(milestoneDay(item)!)}) y no está hecho.',
        ),
        <String>[milestoneLink(item)],
      );
    }
    for (final SIV2HabitEvidence habit in habits.take(3)) {
      fact(
        t(
          'Habit "${habit.title}" has no check-in in the last 14 days.',
          'El hábito "${habit.title}" no tiene registros en los últimos 14 días.',
        ),
        <String>[habitLink(habit)],
      );
    }
  }

  SIOneTapAnswer fallingBehind() {
    if (isEmptyAccount) return empty('catch up on', 'poner al día');
    final List<SIV2TaskEvidence> overdue = overdueByWait;
    final List<SIV2GoalEvidence> goals = lateGoals;
    final List<SIV2MilestoneEvidence> milestones = lateMilestones;
    final List<SIV2HabitEvidence> habits = quietHabits;
    final int total =
        overdue.length + goals.length + milestones.length + habits.length;
    missing(
      t(
        'Tasks with no date cannot be late, and a habit counts as quiet only after 14 days with no check-in.',
        'Las tareas sin fecha no pueden estar atrasadas, y un hábito cuenta como inactivo solo tras 14 días sin registros.',
      ),
    );
    if (total == 0) {
      return finish(
        direct: t(
          'Nothing I can read is behind: no task is overdue, no goal or milestone is past its date, and no habit has gone quiet.',
          'Nada de lo que puedo leer va atrasado: ninguna tarea está vencida, ninguna meta ni hito pasó su fecha y ningún hábito está inactivo.',
        ),
        recommendation: t(
          'Keep your current pace. Nothing was changed.',
          'Mantén tu ritmo actual. No se cambió nada.',
        ),
      );
    }
    _behindFacts(overdue, goals, milestones, habits);
    final String first = overdue.isNotEmpty
        ? t(
            'Start with "${overdue.first.title}", which has waited longest (${timing(overdue.first)}).',
            'Empieza con "${overdue.first.title}", que lleva más tiempo esperando (${timing(overdue.first)}).',
          )
        : goals.isNotEmpty
        ? t(
            'Look at goal "${goals.first.title}" first.',
            'Mira primero la meta "${goals.first.title}".',
          )
        : milestones.isNotEmpty
        ? t(
            'Look at milestone "${milestones.first.title}" first.',
            'Mira primero el hito "${milestones.first.title}".',
          )
        : t(
            'Check in with "${habits.first.title}" when you can.',
            'Registra "${habits.first.title}" cuando puedas.',
          );
    return finish(
      direct: t(
        '${count(total, 'thing is', 'things are', 'cosa va', 'cosas van')} behind: ${overdue.length} overdue ${overdue.length == 1 ? 'task' : 'tasks'}, ${goals.length} ${goals.length == 1 ? 'goal' : 'goals'} and ${milestones.length} ${milestones.length == 1 ? 'milestone' : 'milestones'} past their date, and ${habits.length} quiet ${habits.length == 1 ? 'habit' : 'habits'}.',
        '${count(total, 'cosa va', 'cosas van', 'cosa va', 'cosas van')} atrasada${total == 1 ? '' : 's'}: ${overdue.length} ${overdue.length == 1 ? 'tarea vencida' : 'tareas vencidas'}, ${goals.length} ${goals.length == 1 ? 'meta' : 'metas'} y ${milestones.length} ${milestones.length == 1 ? 'hito' : 'hitos'} fuera de fecha, y ${habits.length} ${habits.length == 1 ? 'hábito inactivo' : 'hábitos inactivos'}.',
      ),
      recommendation:
          '$first ${t('Nothing was changed.', 'No se cambió nada.')}',
    );
  }

  SIOneTapAnswer getBackOnTrack() {
    if (isEmptyAccount) return empty('get back on track with', 'retomar');
    final List<SIV2TaskEvidence> overdue = overdueByWait;
    final List<SIV2GoalEvidence> goals = lateGoals;
    final List<SIV2HabitEvidence> habits = quietHabits;
    missing(
      t(
        'Why things slipped is not recorded, so this only shows what is open.',
        'No se registra por qué se atrasaron las cosas, así que esto solo muestra lo que está abierto.',
      ),
    );
    if (overdue.isEmpty && goals.isEmpty && habits.isEmpty) {
      return finish(
        direct: t(
          'You are not behind on anything I can read: no task is overdue, no goal is past its date and no habit has gone quiet.',
          'No estás atrasado en nada que pueda leer: ninguna tarea está vencida, ninguna meta pasó su fecha y ningún hábito está inactivo.',
        ),
        recommendation: t(
          'There is nothing to catch up on. Keep going at your own pace. Nothing was changed.',
          'No hay nada que recuperar. Sigue a tu ritmo. No se cambió nada.',
        ),
      );
    }
    _behindFacts(overdue, goals, const <SIV2MilestoneEvidence>[], habits);
    infer(
      t(
        'One small step is easier to start than a full catch-up.',
        'Un paso pequeño es más fácil de empezar que ponerse al día con todo.',
      ),
    );
    final String step = overdue.isNotEmpty
        ? t(
            'Do just one thing first: "${overdue.first.title}" (${timing(overdue.first)}).',
            'Haz solo una cosa primero: "${overdue.first.title}" (${timing(overdue.first)}).',
          )
        : habits.isNotEmpty
        ? t(
            'Do just one thing first: check in with "${habits.first.title}".',
            'Haz solo una cosa primero: registra "${habits.first.title}".',
          )
        : t(
            'Do just one thing first: open goal "${goals.first.title}" and pick its next step.',
            'Haz solo una cosa primero: abre la meta "${goals.first.title}" y elige su siguiente paso.',
          );
    return finish(
      direct: t(
        'You are behind on ${overdue.length} overdue ${overdue.length == 1 ? 'task' : 'tasks'}, ${goals.length} ${goals.length == 1 ? 'goal' : 'goals'} past ${goals.length == 1 ? 'its' : 'their'} date and ${habits.length} quiet ${habits.length == 1 ? 'habit' : 'habits'}.',
        'Tienes ${overdue.length} ${overdue.length == 1 ? 'tarea vencida' : 'tareas vencidas'}, ${goals.length} ${goals.length == 1 ? 'meta fuera de fecha' : 'metas fuera de fecha'} y ${habits.length} ${habits.length == 1 ? 'hábito inactivo' : 'hábitos inactivos'}.',
      ),
      recommendation:
          '$step ${t('Everything else can wait until it is done. If something no longer matters, you can move or remove it yourself. Nothing was changed.', 'Lo demás puede esperar. Si algo ya no importa, puedes moverlo o quitarlo tú. No se cambió nada.')}',
      offerAi: true,
    );
  }
}
