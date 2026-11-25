part of 'si_one_tap_engine.dart';

extension _GoalAndRoutineQuestions on _Run {
  // -------------------------------------------------------------- Reach goal

  SIOneTapAnswer reachGoal(String? goalId) {
    final List<SIV2GoalEvidence> goals = snapshot.goals;
    if (goals.isEmpty) {
      missing(
        t('No active goal is saved.', 'No hay ninguna meta activa guardada.'),
      );
      return finish(
        direct: t(
          'You have no active goal yet, so there is nothing to work toward.',
          'Todavía no tienes una meta activa, así que no hay nada hacia lo que avanzar.',
        ),
        recommendation: t(
          'Save a goal in Add something, then ask again. Nothing was changed.',
          'Guarda una meta en Añadir algo y vuelve a preguntar. No se cambió nada.',
        ),
        offerAdd: true,
      );
    }
    SIV2GoalEvidence? goal;
    if (goalId != null) {
      for (final SIV2GoalEvidence g in goals) {
        if (g.id == goalId) goal = g;
      }
    } else if (goals.length == 1) {
      goal = goals.single;
    }
    if (goal == null) {
      missing(
        t(
          'Which goal you mean is not known.',
          'No se sabe a qué meta te refieres.',
        ),
      );
      fact(
        t(
          '${count(goals.length, 'active goal is', 'active goals are', 'meta activa está', 'metas activas están')} saved.',
          '${count(goals.length, 'meta activa está', 'metas activas están', 'meta activa está', 'metas activas están')} guardada${goals.length == 1 ? '' : 's'}.',
        ),
        <String>[goalsGroup],
      );
      return finish(
        direct: goalId == null
            ? t(
                'You have ${goals.length} active goals. Choose one and I can look at it.',
                'Tienes ${goals.length} metas activas. Elige una y la reviso.',
              )
            : t(
                'That goal is no longer saved or active.',
                'Esa meta ya no está guardada o activa.',
              ),
        recommendation: t(
          'Ask again and choose a goal from the list.',
          'Pregunta de nuevo y elige una meta de la lista.',
        ),
      );
    }
    final SIV2GoalEvidence chosen = goal;
    final String goalRef = goalLink(chosen);
    final List<SIV2TaskEvidence> linked =
        tasks
            .where((SIV2TaskEvidence task) => task.goalId == chosen.id)
            .toList()
          ..sort(compareTasks);
    final int tasksTotal = chosen.linkedTasksDone + chosen.linkedTasksOpen;
    final int milestonesTotal = chosen.milestonesDone + chosen.milestonesOpen;
    final DateTime? target = chosen.targetDate == null ? null : goalDay(chosen);

    if (target != null) {
      final int days = daysFromToday(target);
      fact(
        days < 0
            ? t(
                'The target date, ${dateLabel(target)}, passed ${count(-days, 'day', 'days', 'día', 'días')} ago.',
                'La fecha objetivo, ${dateLabel(target)}, pasó hace ${count(-days, 'día', 'días', 'día', 'días')}.',
              )
            : days == 0
            ? t(
                'The target date is today (${dateLabel(target)}).',
                'La fecha objetivo es hoy (${dateLabel(target)}).',
              )
            : t(
                'The target date is ${dateLabel(target)}, in ${count(days, 'day', 'days', 'día', 'días')}.',
                'La fecha objetivo es el ${dateLabel(target)}, dentro de ${count(days, 'día', 'días', 'día', 'días')}.',
              ),
        <String>[goalRef],
      );
    } else {
      missing(
        t(
          'This goal has no target date.',
          'Esta meta no tiene fecha objetivo.',
        ),
      );
    }
    if (tasksTotal > 0) {
      calc(
        t(
          '${chosen.linkedTasksDone} of ${count(tasksTotal, 'linked task', 'linked tasks', 'tarea vinculada', 'tareas vinculadas')} ${chosen.linkedTasksDone == 1 ? 'is' : 'are'} done.',
          '${chosen.linkedTasksDone} de ${count(tasksTotal, 'tarea vinculada', 'tareas vinculadas', 'tarea vinculada', 'tareas vinculadas')} ${chosen.linkedTasksDone == 1 ? 'está hecha' : 'están hechas'}.',
        ),
        <String>[goalRef],
      );
    }
    if (milestonesTotal > 0) {
      calc(
        t(
          '${chosen.milestonesDone} of ${count(milestonesTotal, 'milestone', 'milestones', 'hito', 'hitos')} ${chosen.milestonesDone == 1 ? 'is' : 'are'} done.',
          '${chosen.milestonesDone} de ${count(milestonesTotal, 'hito', 'hitos', 'hito', 'hitos')} ${chosen.milestonesDone == 1 ? 'está hecho' : 'están hechos'}.',
        ),
        <String>[goalRef],
      );
    }
    for (final SIV2TaskEvidence task in linked.take(4)) {
      fact('"${task.title}" · ${timing(task)}', <String>[taskId(task)]);
    }
    if (tasksTotal + milestonesTotal == 0) {
      missing(
        t(
          'No task or milestone is linked to this goal, so how far along it is cannot be told.',
          'Ninguna tarea ni hito está vinculado a esta meta, así que no se puede saber cuánto ha avanzado.',
        ),
      );
    } else {
      missing(
        t(
          'Progress counts only the tasks and milestones you linked to this goal.',
          'El avance cuenta solo las tareas e hitos que vinculaste a esta meta.',
        ),
      );
    }
    final bool hasNext = linked.isNotEmpty;
    final String progress = tasksTotal + milestonesTotal == 0
        ? t('Nothing is linked to it yet.', 'Todavía no hay nada vinculado.')
        : t(
            '${chosen.linkedTasksDone} of $tasksTotal linked ${tasksTotal == 1 ? 'task is' : 'tasks are'} done${milestonesTotal > 0 ? ' and ${chosen.milestonesDone} of $milestonesTotal ${milestonesTotal == 1 ? 'milestone' : 'milestones'}' : ''}.',
            '${chosen.linkedTasksDone} de $tasksTotal ${tasksTotal == 1 ? 'tarea vinculada está hecha' : 'tareas vinculadas están hechas'}${milestonesTotal > 0 ? ' y ${chosen.milestonesDone} de $milestonesTotal ${milestonesTotal == 1 ? 'hito' : 'hitos'}' : ''}.',
          );
    return finish(
      direct: t(
        'Goal "${chosen.title}": $progress',
        'Meta "${chosen.title}": $progress',
      ),
      recommendation: hasNext
          ? t(
              'Take the next step on "${linked.first.title}" (${timing(linked.first)}). Nothing was changed.',
              'Da el siguiente paso en "${linked.first.title}" (${timing(linked.first)}). No se cambió nada.',
            )
          : t(
              'Add one small first step for this goal in Add something, where you review it before it is saved. Nothing was changed.',
              'Añade un primer paso pequeño para esta meta en Añadir algo, donde lo revisas antes de guardarlo. No se cambió nada.',
            ),
      offerAdd: !hasNext,
      offerAi: true,
    );
  }

  // --------------------------------------------------------- Improve routine

  /// How many periods of its current frequency fit in the window, or null
  /// when there are too few to judge (under 3 days, under 2 weeks) or the
  /// habit is monthly. Counted from when the frequency began: a habit whose
  /// frequency was edited is not judged against the old one.
  int? _periods(SIV2HabitEvidence habit) {
    final int days = oneTapDaysBetween(habit.trackedSince.toLocal(), now) + 1;
    final int span = days < habit.windowDays ? days : habit.windowDays;
    return switch (habit.cadence) {
      HabitCadence.daily => span >= 3 ? span : null,
      HabitCadence.weekly => span >= 14 ? 2 : null,
      HabitCadence.monthly => null,
    };
  }

  /// A habit records one outcome per period, whatever its "times per period"
  /// is set to, so check-ins are counted in periods.
  int _checked(SIV2HabitEvidence h) {
    final int? periods = _periods(h);
    return periods != null && h.checkInsSinceTracked > periods
        ? periods
        : h.checkInsSinceTracked;
  }

  String _habitLine(SIV2HabitEvidence h) {
    final int? periods = _periods(h);
    final String text = switch (h.cadence) {
      HabitCadence.daily when periods != null => t(
        'checked in on ${_checked(h)} of the last $periods days',
        'registrado ${_checked(h)} de los últimos $periods días',
      ),
      HabitCadence.weekly when periods != null => t(
        'checked in in ${_checked(h)} of the last $periods weeks',
        'registrado en ${_checked(h)} de las últimas $periods semanas',
      ),
      _ => t(
        '${count(h.checkInsInWindow, 'check-in', 'check-ins', 'registro', 'registros')} in the last 14 days',
        '${count(h.checkInsInWindow, 'registro', 'registros', 'registro', 'registros')} en los últimos 14 días',
      ),
    };
    final String cadence = switch (h.cadence) {
      HabitCadence.daily => t('daily', 'diario'),
      HabitCadence.weekly => t('weekly', 'semanal'),
      HabitCadence.monthly => t('monthly', 'mensual'),
    };
    return t(
      '"${h.title}" · $cadence · $text · streak ${h.currentStreak}',
      '"${h.title}" · $cadence · $text · racha ${h.currentStreak}',
    );
  }

  SIOneTapAnswer improveRoutine() {
    final List<SIV2HabitEvidence> habits = snapshot.habits;
    if (habits.isEmpty) {
      missing(t('No habit is saved.', 'No hay ningún hábito guardado.'));
      return finish(
        direct: t(
          'You have no habits saved yet, so there is no routine to improve.',
          'Todavía no tienes hábitos guardados, así que no hay una rutina que mejorar.',
        ),
        recommendation: t(
          'Save one small habit in Add something, where you review it before it is saved. Nothing was changed.',
          'Guarda un hábito pequeño en Añadir algo, donde lo revisas antes de guardarlo. No se cambió nada.',
        ),
        offerAdd: true,
      );
    }
    final List<SIV2HabitEvidence> judged = habits
        .where((SIV2HabitEvidence h) => _periods(h) != null)
        .toList(growable: false);
    double ratio(SIV2HabitEvidence h) => _checked(h) / _periods(h)!;
    // Most check-ins first; ties by title, then id, so the order is stable.
    judged.sort((a, b) {
      final int byRatio = ratio(b).compareTo(ratio(a));
      if (byRatio != 0) return byRatio;
      final int byTitle = a.title.compareTo(b.title);
      return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
    });
    for (final SIV2HabitEvidence h in habits.take(5)) {
      fact(_habitLine(h), <String>[habitLink(h)]);
    }
    final int withCheckIn = habits
        .where((SIV2HabitEvidence h) => h.checkInsInWindow > 0)
        .length;
    calc(
      t(
        '$withCheckIn of ${habits.length} ${habits.length == 1 ? 'habit has' : 'habits have'} a check-in in the last 14 days.',
        '$withCheckIn de ${habits.length} ${habits.length == 1 ? 'hábito tiene' : 'hábitos tienen'} un registro en los últimos 14 días.',
      ),
      <String>[habitsGroup],
    );
    missing(
      t(
        'A habit records one check-in per period, whatever times per period it is set to. The time of day and how each check-in felt are not recorded.',
        'Un hábito registra un solo registro por período, sin importar cuántas veces por período esté configurado. No se registran la hora del día ni cómo se sintió cada registro.',
      ),
    );
    final int tooNew = habits.length - judged.length;
    if (tooNew > 0) {
      missing(
        t(
          '${count(tooNew, 'habit is', 'habits are', 'hábito es', 'hábitos son')} too new, or too infrequent, to judge from 14 days.',
          '${count(tooNew, 'hábito es', 'hábitos son', 'hábito es', 'hábitos son')} demasiado nuevo${tooNew == 1 ? '' : 's'}, o poco frecuente${tooNew == 1 ? '' : 's'}, para juzgar con 14 días.',
        ),
      );
    }
    String recommendation;
    final String unchanged = t('Nothing was changed.', 'No se cambió nada.');
    if (judged.isEmpty) {
      recommendation = t(
        'Give your habits a few more days of check-ins, then ask again. $unchanged',
        'Dale a tus hábitos unos días más de registros y pregunta de nuevo. $unchanged',
      );
    } else if (judged.length == 1 ||
        ratio(judged.first) == ratio(judged.last)) {
      recommendation = t(
        'The records show the same pattern for each habit that can be judged. Whether to change any habit is up to you. $unchanged',
        'Los registros muestran el mismo patrón en cada hábito que se puede juzgar. Si cambiar algún hábito o no, lo decides tú. $unchanged',
      );
    } else {
      final SIV2HabitEvidence most = judged.first;
      final SIV2HabitEvidence fewest = judged.last;
      recommendation = t(
        'The records show the highest share of check-ins on "${most.title}" (${_checked(most)} of ${_periods(most)}) and the lowest on "${fewest.title}" (${_checked(fewest)} of ${_periods(fewest)}). Whether and how to change a habit is up to you. $unchanged',
        'Los registros muestran la mayor proporción de registros en "${most.title}" (${_checked(most)} de ${_periods(most)}) y la menor en "${fewest.title}" (${_checked(fewest)} de ${_periods(fewest)}). Si cambiar un hábito y cómo, lo decides tú. $unchanged',
      );
    }
    return finish(
      direct: t(
        'You have ${count(habits.length, 'habit', 'habits', 'hábito', 'hábitos')}. Over the last 14 days, $withCheckIn ${withCheckIn == 1 ? 'has' : 'have'} a check-in and ${habits.length - withCheckIn} ${habits.length - withCheckIn == 1 ? 'has' : 'have'} none.',
        'Tienes ${count(habits.length, 'hábito', 'hábitos', 'hábito', 'hábitos')}. En los últimos 14 días, $withCheckIn ${withCheckIn == 1 ? 'tiene' : 'tienen'} registros y ${habits.length - withCheckIn} no ${habits.length - withCheckIn == 1 ? 'tiene' : 'tienen'}.',
      ),
      recommendation: recommendation,
      offerAi: true,
    );
  }
}
