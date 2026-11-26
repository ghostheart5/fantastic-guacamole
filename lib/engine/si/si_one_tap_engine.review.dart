part of 'si_one_tap_engine.dart';

extension _PatternAndWeekQuestions on _Run {
  // -------------------------------------------------------- Explain patterns

  String _weekday(int weekday) => const <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][weekday - 1];

  String _weekdayEs(int weekday) => const <String>[
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ][weekday - 1];

  SIOneTapAnswer explainPatterns() {
    if (isEmptyAccount) return empty('find a pattern in', 'ver como patrón');
    final List<SIV2RecentTaskEvidence> recent = snapshot.recentTasks;
    final List<SIV2RecentTaskEvidence> done = recent
        .where(
          (SIV2RecentTaskEvidence r) =>
              r.outcome == SIV2RecentTaskOutcome.completed,
        )
        .toList(growable: false);
    final int skipped = recent.length - done.length;
    missing(
      t(
        'These are patterns in what was recorded, not reasons. Why something happened is not stored.',
        'Son patrones de lo registrado, no razones. No se guarda por qué pasó algo.',
      ),
    );
    if (recent.isNotEmpty) {
      fact(
        t(
          '${count(done.length, 'task was', 'tasks were', 'tarea fue', 'tareas fueron')} finished and $skipped skipped in the last 14 days.',
          '${count(done.length, 'tarea terminada', 'tareas terminadas', 'tarea terminada', 'tareas terminadas')} y $skipped ${skipped == 1 ? 'omitida' : 'omitidas'} en los últimos 14 días.',
        ),
        <String>[recentGroup],
      );
    }
    for (final SIV2HabitEvidence h in snapshot.habits.take(3)) {
      fact(_habitLine(h), <String>[habitLink(h)]);
    }
    final bool enough = done.length >= _patternMinimum;
    String direct;
    if (!enough) {
      missing(
        t(
          'Only ${count(done.length, 'finished task', 'finished tasks', 'tarea terminada', 'tareas terminadas')} in the last 14 days; at least $_patternMinimum are needed to show a pattern.',
          'Solo ${count(done.length, 'tarea terminada', 'tareas terminadas', 'tarea terminada', 'tareas terminadas')} en los últimos 14 días; hacen falta al menos $_patternMinimum para ver un patrón.',
        ),
      );
      direct = t(
        'There is too little history to show a pattern yet.',
        'Todavía hay muy poco historial para mostrar un patrón.',
      );
    } else {
      final Map<int, int> byDay = <int, int>{};
      final Map<String, int> byPart = <String, int>{};
      for (final SIV2RecentTaskEvidence r in done) {
        final DateTime at = r.at.toLocal();
        byDay.update(at.weekday, (int v) => v + 1, ifAbsent: () => 1);
        final String part = at.hour < 6
            ? 'night'
            : at.hour < 12
            ? 'morning'
            : at.hour < 17
            ? 'afternoon'
            : 'evening';
        byPart.update(part, (int v) => v + 1, ifAbsent: () => 1);
      }
      final List<String> lines = <String>[];
      missing(
        t(
          'Days and times are when a task was marked done, which may differ from when the work was done.',
          'Los días y horas son cuando se marcó una tarea como hecha, que puede diferir de cuando se hizo el trabajo.',
        ),
      );
      // A day counts only when it has at least 3 and strictly more than any
      // other day: a tie is no pattern.
      final List<MapEntry<int, int>> days = byDay.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (days.first.value >= 3 &&
          (days.length == 1 || days.first.value > days[1].value)) {
        calc(
          t(
            '${days.first.value} of ${done.length} finished tasks were marked done on a ${_weekday(days.first.key)}; no other day has as many.',
            '${days.first.value} de ${done.length} tareas terminadas se marcaron como hechas un ${_weekdayEs(days.first.key)}; ningún otro día tiene tantas.',
          ),
          <String>[recentGroup],
        );
        lines.add(
          t(
            '${days.first.value} of ${done.length} finished tasks were marked done on a ${_weekday(days.first.key)}.',
            '${days.first.value} de ${done.length} tareas terminadas se marcaron como hechas un ${_weekdayEs(days.first.key)}.',
          ),
        );
      }
      final MapEntry<String, int> part = byPart.entries.reduce(
        (a, b) => b.value > a.value ? b : a,
      );
      if (part.value >= 3 && part.value * 2 > done.length) {
        final String en = switch (part.key) {
          'night' => 'at night (midnight to 5:59)',
          'morning' => 'in the morning (6:00 to 11:59)',
          'afternoon' => 'in the afternoon (12:00 to 16:59)',
          _ => 'in the evening (17:00 to 23:59)',
        };
        final String es = switch (part.key) {
          'night' => 'de madrugada (de 0:00 a 5:59)',
          'morning' => 'por la mañana (de 6:00 a 11:59)',
          'afternoon' => 'por la tarde (de 12:00 a 16:59)',
          _ => 'por la noche (de 17:00 a 23:59)',
        };
        calc(
          t(
            '${part.value} of ${done.length} finished tasks were marked done $en.',
            '${part.value} de ${done.length} tareas terminadas se marcaron como hechas $es.',
          ),
          <String>[recentGroup],
        );
        lines.add(
          t(
            '${part.value} of ${done.length} finished tasks were marked done $en.',
            '${part.value} de ${done.length} tareas terminadas se marcaron como hechas $es.',
          ),
        );
      }
      final int overdue = tasks.where(isOverdue).length;
      if (skipped > 0) {
        calc(
          t(
            'Skipped tasks are ${(skipped * 100 / recent.length).round()}% of those finished or skipped.',
            'Las tareas omitidas son el ${(skipped * 100 / recent.length).round()}% de las terminadas u omitidas.',
          ),
          <String>[recentGroup],
        );
      }
      if (overdue > 0) {
        lines.add(
          t(
            '${count(overdue, 'task is', 'tasks are', 'tarea está', 'tareas están')} overdue.',
            '${count(overdue, 'tarea está', 'tareas están', 'tarea está', 'tareas están')} vencida${overdue == 1 ? '' : 's'}.',
          ),
        );
      }
      direct = lines.isEmpty
          ? t(
              'The last 14 days show no clear pattern: ${done.length} finished and $skipped skipped, spread without a standout day or time.',
              'Los últimos 14 días no muestran un patrón claro: ${done.length} terminadas y $skipped omitidas, sin un día u hora destacados.',
            )
          : lines.join(' ');
      infer(
        t(
          'A pattern from 14 days can change; treat it as a hint.',
          'Un patrón de 14 días puede cambiar; tómalo como una pista.',
        ),
      );
    }
    return finish(
      direct: direct,
      recommendation: enough
          ? t(
              'Use this as a hint when you plan, and keep tracking. Nothing was changed.',
              'Úsalo como pista al planear y sigue registrando. No se cambió nada.',
            )
          : t(
              'Keep finishing or skipping tasks as you go; patterns appear after about $_patternMinimum. Nothing was changed.',
              'Sigue terminando u omitiendo tareas; los patrones aparecen tras unas $_patternMinimum. No se cambió nada.',
            ),
      offerAi: true,
    );
  }

  // ------------------------------------------------------------- Review week

  SIOneTapAnswer reviewWeek() {
    if (isEmptyAccount) {
      return empty('review for your week', 'revisar en tu semana');
    }
    final DateTime weekStart = oneTapAddDays(today, -6);
    final DateTime prevStart = oneTapAddDays(today, -13);
    int doneThis = 0;
    int skippedThis = 0;
    int donePrev = 0;
    for (final SIV2RecentTaskEvidence r in snapshot.recentTasks) {
      final DateTime day = DateTime(
        r.at.toLocal().year,
        r.at.toLocal().month,
        r.at.toLocal().day,
      );
      final bool completed = r.outcome == SIV2RecentTaskOutcome.completed;
      if (!day.isBefore(weekStart)) {
        completed ? doneThis++ : skippedThis++;
      } else if (!day.isBefore(prevStart) && completed) {
        donePrev++;
      }
    }
    final int overdue = tasks.where(isOverdue).length;
    final int nextWeek = tasks.where((SIV2TaskEvidence task) {
      if (isOverdue(task)) return false;
      final DateTime? day = taskDay(task);
      return day != null &&
          !day.isBefore(today) &&
          day.isBefore(oneTapAddDays(today, 8));
    }).length;
    final int habitCheckIns = snapshot.habits.fold(
      0,
      (int sum, SIV2HabitEvidence h) => sum + h.checkInsInWindow,
    );
    fact(
      t(
        'In the last 7 days, ${count(doneThis, 'task was', 'tasks were', 'tarea se terminó', 'tareas se terminaron')} finished and $skippedThis skipped.',
        'En los últimos 7 días se ${doneThis == 1 ? 'terminó' : 'terminaron'} $doneThis ${doneThis == 1 ? 'tarea' : 'tareas'} y ${skippedThis == 1 ? 'se omitió' : 'se omitieron'} $skippedThis.',
      ),
      <String>[recentGroup],
    );
    fact(
      t(
        'In the 7 days before that, $donePrev ${donePrev == 1 ? 'task was' : 'tasks were'} finished.',
        'En los 7 días anteriores se ${donePrev == 1 ? 'terminó' : 'terminaron'} $donePrev ${donePrev == 1 ? 'tarea' : 'tareas'}.',
      ),
      <String>[recentGroup],
    );
    if (snapshot.habits.isNotEmpty) {
      fact(
        t(
          '${count(habitCheckIns, 'habit check-in', 'habit check-ins', 'registro de hábito', 'registros de hábitos')} in the last 14 days across ${count(snapshot.habits.length, 'habit', 'habits', 'hábito', 'hábitos')}.',
          '${count(habitCheckIns, 'registro de hábito', 'registros de hábitos', 'registro de hábito', 'registros de hábitos')} en los últimos 14 días en ${count(snapshot.habits.length, 'hábito', 'hábitos', 'hábito', 'hábitos')}.',
        ),
        <String>[habitsGroup],
      );
    }
    if (tasks.isNotEmpty) {
      fact(
        t(
          '${count(overdue, 'open task is', 'open tasks are', 'tarea abierta está', 'tareas abiertas están')} overdue and $nextWeek ${nextWeek == 1 ? 'is' : 'are'} due or planned in the next 7 days.',
          '${count(overdue, 'tarea abierta está', 'tareas abiertas están', 'tarea abierta está', 'tareas abiertas están')} vencida${overdue == 1 ? '' : 's'} y $nextWeek ${nextWeek == 1 ? 'es' : 'son'} para los próximos 7 días.',
        ),
        <String>[tasksGroup],
      );
    }
    missing(
      t(
        'Habit check-ins are counted over 14 days, not 7. Tasks finished without a recorded time are not counted.',
        'Los registros de hábitos se cuentan en 14 días, no 7. Las tareas terminadas sin hora registrada no se cuentan.',
      ),
    );
    if (snapshot.recentTasks.isEmpty) {
      missing(
        t(
          'No task was finished or skipped in the last 14 days, so there is no week to compare.',
          'Ninguna tarea se terminó ni se omitió en los últimos 14 días, así que no hay semana que comparar.',
        ),
      );
    }
    final String trend = doneThis > donePrev
        ? t('more than the week before', 'más que la semana anterior')
        : doneThis < donePrev
        ? t('fewer than the week before', 'menos que la semana anterior')
        : t('the same as the week before', 'lo mismo que la semana anterior');
    return finish(
      direct: snapshot.recentTasks.isEmpty
          ? t(
              'No task was finished or skipped in the last 7 days.',
              'Ninguna tarea se terminó ni se omitió en los últimos 7 días.',
            )
          : t(
              'This week, $doneThis ${doneThis == 1 ? 'task was' : 'tasks were'} finished and $skippedThis skipped: $trend ($donePrev).',
              'Esta semana se ${doneThis == 1 ? 'terminó' : 'terminaron'} $doneThis ${doneThis == 1 ? 'tarea' : 'tareas'} y ${skippedThis == 1 ? 'se omitió' : 'se omitieron'} $skippedThis: $trend ($donePrev).',
            ),
      recommendation: overdue > 0
          ? t(
              'Start next week with the $overdue overdue ${overdue == 1 ? 'task' : 'tasks'}. Nothing was changed.',
              'Empieza la próxima semana con ${overdue == 1 ? 'la tarea vencida' : 'las $overdue tareas vencidas'}. No se cambió nada.',
            )
          : t(
              'Nothing is overdue. Next week has $nextWeek ${nextWeek == 1 ? 'item' : 'items'} with a date. Nothing was changed.',
              'No hay nada vencido. La próxima semana tiene $nextWeek ${nextWeek == 1 ? 'elemento' : 'elementos'} con fecha. No se cambió nada.',
            ),
      offerAi: true,
    );
  }
}
