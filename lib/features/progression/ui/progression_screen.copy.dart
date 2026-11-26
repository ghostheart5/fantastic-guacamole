part of 'progression_screen.dart';

/// Every sentence on Patterns, in English and Spanish. Nothing here is a
/// prediction: figures are counted from records or read from the plan.
class _PatternsCopy {
  const _PatternsCopy(this.es);

  /// The same language switch as journeyText.
  factory _PatternsCopy.of(BuildContext context) =>
      _PatternsCopy(ChronoSparkLocalizations.of(context).isSpanish);

  final bool es;

  String _t(String en, String sp) => es ? sp : en;

  static const List<String> _weekdaysEn = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const List<String> _weekdaysEs = <String>[
    'lun',
    'mar',
    'mié',
    'jue',
    'vie',
    'sáb',
    'dom',
  ];
  static const List<String> _monthsEn = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const List<String> _monthsEs = <String>[
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  static const List<String> _fullMonthsEn = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const List<String> _fullMonthsEs = <String>[
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  /// "30 Nov" / "30 nov".
  String dayMonth(DateTime d) =>
      '${d.day} ${(es ? _monthsEs : _monthsEn)[d.month - 1]}';

  /// "Mon 30 Nov" / "lun 30 nov".
  String date(DateTime d) =>
      '${(es ? _weekdaysEs : _weekdaysEn)[d.weekday - 1]} ${dayMonth(d)}';

  String _count(int n, String one, String many) => '$n ${n == 1 ? one : many}';

  // Page.
  String get timeRange => _t('Time range', 'Periodo');
  String rangeLabel(int days) => _t('$days days', '$days días');
  String get reading => _t('Reading your records…', 'Leyendo tus registros…');
  String get updating =>
      _t('Updating from your records…', 'Actualizando con tus registros…');
  String get unreadable => _t(
    'Your records could not be read, so no figures are shown.',
    'No se pudieron leer tus registros, así que no se muestran cifras.',
  );
  String get retry => _t('Retry', 'Reintentar');
  String get openMyPlan => _t('Open My plan', 'Abrir Mi plan');
  String get addSomething => _t('Add something', 'Añadir algo');

  // Habits.
  String get habits => _t('Habits', 'Hábitos');
  String get habitsDescription => _t(
    'Check-ins over the period on each line. The current day, week or month '
        'is included.',
    'Registros en el periodo de cada línea. Se incluye el día, la semana o '
        'el mes en curso.',
  );
  String get noHabits => _t(
    'No active habits yet. Add a habit and check in to see it here.',
    'Aún no tienes hábitos activos. Añade un hábito y regístralo para verlo '
        'aquí.',
  );

  String periods(HabitCadence cadence, int n) => switch (cadence) {
    HabitCadence.daily =>
      es ? _count(n, 'día', 'días') : _count(n, 'day', 'days'),
    HabitCadence.weekly =>
      es ? _count(n, 'semana', 'semanas') : _count(n, 'week', 'weeks'),
    HabitCadence.monthly =>
      es ? _count(n, 'mes', 'meses') : _count(n, 'month', 'months'),
  };

  /// "6 of 7 days" / "2 de 4 semanas".
  String consistency(HabitCadence cadence, int done, int window) {
    final String total = periods(cadence, window);
    return _t('$done of $total', '$done de $total');
  }

  String streaks(HabitCadence cadence, int current, int longest) => _t(
    'Streak: ${periods(cadence, current)} · Longest: '
        '${periods(cadence, longest)}',
    'Racha: ${periods(cadence, current)} · Más larga: '
        '${periods(cadence, longest)}',
  );

  String _thisPeriod(HabitCadence cadence) => switch (cadence) {
    HabitCadence.daily => _t('today', 'hoy'),
    HabitCadence.weekly => _t('this week', 'esta semana'),
    HabitCadence.monthly => _t('this month', 'este mes'),
  };

  String skippedNow(HabitCadence cadence) => _t(
    'Skipped ${_thisPeriod(cadence)}.',
    'Omitido ${_thisPeriod(cadence)}.',
  );
  String openNow(HabitCadence cadence) => _t(
    'Not checked in ${_thisPeriod(cadence)} yet.',
    'Aún sin registrar ${_thisPeriod(cadence)}.',
  );
  String get notEnoughHistory =>
      _t('Not enough history yet', 'Aún no hay suficiente historial');
  String startedNow(HabitCadence cadence) => _t(
    'Tracking started ${_thisPeriod(cadence)}.',
    'El seguimiento empezó ${_thisPeriod(cadence)}.',
  );

  // Trend.
  String get trend => _t(
    'Tasks finished and habit check-ins',
    'Tareas terminadas y registros de hábitos',
  );
  String trendDescription(int bucketDays, int coveredDays) {
    if (bucketDays == 1) {
      return _t(
        'The last $coveredDays days, day by day.',
        'Los últimos $coveredDays días, día a día.',
      );
    }
    final int weeks = coveredDays ~/ 7;
    return _t(
      'The last $weeks weeks, week by week.',
      'Las últimas $weeks semanas, semana a semana.',
    );
  }

  String get trendEmpty => _t(
    'Nothing recorded in these days. Finish a task or check in a habit to '
        'see it here.',
    'No hay nada registrado en estos días. Termina una tarea o registra un '
        'hábito para verlo aquí.',
  );
  String get tasksFinished => _t('Tasks finished', 'Tareas terminadas');
  String get habitCheckIns => _t('Habit check-ins', 'Registros de hábitos');
  String get today => _t('Today', 'Hoy');
  String get yesterday => _t('Yesterday', 'Ayer');
  String get tomorrow => _t('Tomorrow', 'Mañana');

  /// "25 Nov – 1 Dec" for a stretch of days ([end] exclusive).
  String span(DateTime start, DateTime endExclusive) {
    final DateTime last = DateTime(
      endExclusive.year,
      endExclusive.month,
      endExclusive.day - 1,
    );
    return '${dayMonth(start)} – ${dayMonth(last)}';
  }

  String tasks(int n) =>
      es ? _count(n, 'tarea', 'tareas') : _count(n, 'task', 'tasks');
  String checkIns(int n) => es
      ? _count(n, 'registro', 'registros')
      : _count(n, 'check-in', 'check-ins');
  String bucketValue(int tasksDone, int checkInsDone) =>
      '${tasks(tasksDone)} · ${checkIns(checkInsDone)}';

  // When you get things done.
  String get whenDone =>
      _t('When you get things done', 'Cuándo terminas las cosas');
  String whenDoneDescription(int windowDays, DateTime windowStart) {
    final String window = windowDays % 7 == 0
        ? _t(
            'the last ${windowDays ~/ 7} weeks',
            'las últimas ${windowDays ~/ 7} semanas',
          )
        : _t('the last $windowDays days', 'los últimos $windowDays días');
    return _t(
      'Finished tasks in $window (since ${date(windowStart)}), whichever '
          'range is chosen.',
      'Tareas terminadas en $window (desde el ${date(windowStart)}), sea cual '
          'sea el periodo elegido.',
    );
  }

  String whenDoneNotEnough(int have, int need) => _t(
    'Not enough finished tasks yet to see a pattern: $have of the $need '
        'needed.',
    'Aún no hay suficientes tareas terminadas para ver un patrón: $have de '
        'las $need necesarias.',
  );
  String get finishedTasks => _t('Finished tasks', 'Tareas terminadas');
  String get dayOfWeek => _t('Day of the week', 'Día de la semana');
  String get noDayStandsOut =>
      _t('No single day stands out', 'Ningún día destaca');
  String get partOfDay => _t('Part of the day', 'Momento del día');
  String get noPartStandsOut =>
      _t('No part of the day stands out', 'Ningún momento del día destaca');

  String weekdays(int isoWeekday) => (es
      ? const <String>[
          'Los lunes',
          'Los martes',
          'Los miércoles',
          'Los jueves',
          'Los viernes',
          'Los sábados',
          'Los domingos',
        ]
      : const <String>[
          'Mondays',
          'Tuesdays',
          'Wednesdays',
          'Thursdays',
          'Fridays',
          'Saturdays',
          'Sundays',
        ])[isoWeekday - 1];

  String partName(PartOfDay part) => switch (part) {
    PartOfDay.night => _t('Nights', 'De madrugada'),
    PartOfDay.morning => _t('Mornings', 'Por la mañana'),
    PartOfDay.afternoon => _t('Afternoons', 'Por la tarde'),
    PartOfDay.evening => _t('Evenings', 'Por la noche'),
  };

  String _hours(PartOfDay part) => switch (part) {
    PartOfDay.night => _t('0:00 and 5:59', 'las 0:00 y las 5:59'),
    PartOfDay.morning => _t('6:00 and 11:59', 'las 6:00 y las 11:59'),
    PartOfDay.afternoon => _t('12:00 and 16:59', 'las 12:00 y las 16:59'),
    PartOfDay.evening => _t('17:00 and 23:59', 'las 17:00 y las 23:59'),
  };

  String ofFinished(int n, int total) =>
      _t('$n of $total finished tasks', '$n de $total tareas terminadas');
  String ofFinishedBetween(int n, int total, PartOfDay part) => _t(
    '${ofFinished(n, total)}, between ${_hours(part)}',
    '${ofFinished(n, total)}, entre ${_hours(part)}',
  );

  // Workload.
  String get workload => _t('Workload by day', 'Carga de trabajo por día');
  String workloadDescription(int days) => _t(
    'Planned minutes for the next $days days, based on your estimates.',
    'Minutos planificados para los próximos $days días, según tus '
        'estimaciones.',
  );
  String get workloadEmpty => _t(
    'Nothing planned for the next 7 days and no open work without a day.',
    'No hay nada planificado para los próximos 7 días ni trabajo abierto sin '
        'día.',
  );

  /// "45 min", "1 h", "1 h 30 min".
  String minutes(int total) {
    if (total < 60) return '$total min';
    final int h = total ~/ 60;
    final int m = total % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  String _withoutEstimate(int n) => n == 0
      ? ''
      : _t('; $n with no estimate saved', '; $n sin estimación guardada');

  String dayTasks(int count, int withoutEstimate) =>
      '${tasks(count)}${_withoutEstimate(withoutEstimate)}';
  String get notOnADay => _t('Not on a day', 'Sin día asignado');
  String get none => _t('None', 'Ninguna');
  String unplacedCaption(int count, int withoutEstimate) => _t(
    '${tasks(count)} with no date, a date that has passed, or overdue'
        '${_withoutEstimate(withoutEstimate)}',
    '${tasks(count)} sin fecha, con una fecha ya pasada o vencidas'
        '${_withoutEstimate(withoutEstimate)}',
  );
  String workloadFootnote({required bool anyWithoutEstimate}) {
    final String base = _t(
      'All figures are based on your estimates.',
      'Todas las cifras se basan en tus estimaciones.',
    );
    if (!anyWithoutEstimate) return base;
    return _t(
      '$base Tasks with no estimate saved use a standard length.',
      '$base Las tareas sin estimación guardada usan una duración estándar.',
    );
  }

  // Missed items.
  String get missed => _t('Missed items', 'Lo que quedó sin hacer');
  String missedDescription(int rangeDays) => _t(
    'Counts from the last $rangeDays days, and work overdue now.',
    'Recuentos de los últimos $rangeDays días y trabajo vencido ahora.',
  );
  String get missedEmpty => _t(
    'Nothing recorded yet. Add a task or a habit to see it here.',
    'Aún no hay nada registrado. Añade una tarea o un hábito para verlo aquí.',
  );
  String get tasksSkipped => _t('Tasks skipped', 'Tareas omitidas');
  String get overdueNow => _t('Overdue now', 'Vencidas ahora');
  String get habitPeriodsMissed => _t(
    'Habit periods missed or skipped',
    'Periodos de hábitos sin hacer u omitidos',
  );
  String get noTasksYet => _t('No tasks yet', 'Aún no hay tareas');
  String get noHabitsYet => _t('No habits yet', 'Aún no hay hábitos');
  String andMore(int n) => _t('and $n more', 'y $n más');

  String period(HabitCadence cadence, DateTime start) => switch (cadence) {
    HabitCadence.daily => date(start),
    HabitCadence.weekly => _t(
      'week of ${dayMonth(start)}',
      'semana del ${dayMonth(start)}',
    ),
    HabitCadence.monthly =>
      '${(es ? _fullMonthsEs : _fullMonthsEn)[start.month - 1]} ${start.year}',
  };

  String periodState(HabitPeriodState state) =>
      state == HabitPeriodState.skipped
      ? _t('skipped', 'omitido')
      : _t('missed', 'sin hacer');

  // Level and points.
  String get levelAndPoints => _t('Level and points', 'Nivel y puntos');
  String get level => _t('Level', 'Nivel');
  String get points => _t('Points', 'Puntos');
  String pointsToNext(int xp, int nextLevel) =>
      _t('$xp XP until level $nextLevel', '$xp XP para el nivel $nextLevel');
  String get streak => _t('Streak', 'Racha');
  String streakDays(int n) =>
      es ? _count(n, 'día', 'días') : _count(n, 'day', 'days');
  String get progressUnavailable => _t(
    'Your saved progress could not be loaded. No zero-value progress is being '
        'shown.',
    'No se pudo cargar tu progreso guardado. No se muestran valores cero como '
        'si fueran reales.',
  );
  String get shareProgress => _t('Share progress', 'Compartir progreso');
  String get progressSnapshot => _t('Progress snapshot', 'Resumen de progreso');
  String get achievement => _t('Achievement', 'Logro');
}
