part of 'trajectory_engine_screen.dart';

/// Short, sentence-case name of each status, in the current language.
String _trajectoryStatusLabel(
  BuildContext context,
  TrajectoryEngineStatus status,
) => switch (status) {
  TrajectoryEngineStatus.loading => journeyText(
    context,
    'Working out your estimate',
    'Calculando tu estimación',
  ),
  TrajectoryEngineStatus.learning => journeyText(
    context,
    'Learning your pattern',
    'Aprendiendo tu patrón',
  ),
  TrajectoryEngineStatus.ready => journeyText(
    context,
    'Estimate ready',
    'Estimación lista',
  ),
  TrajectoryEngineStatus.empty => journeyText(
    context,
    'Add a task to start',
    'Añade una tarea para empezar',
  ),
  TrajectoryEngineStatus.partial => journeyText(
    context,
    'Some information is missing',
    'Falta algo de información',
  ),
  TrajectoryEngineStatus.offline => journeyText(
    context,
    'Using what is on this device',
    'Usando lo que hay en este dispositivo',
  ),
  TrajectoryEngineStatus.error => journeyText(
    context,
    'The estimate could not be updated',
    'No se pudo actualizar la estimación',
  ),
};

/// The model's status detail in plain words, in the current language. Details
/// this screen does not know are shown as they are.
String _trajectoryStatusDetail(
  BuildContext context,
  TrajectoryEngineStatus status,
  String detail,
) {
  if (status == TrajectoryEngineStatus.learning) {
    final String? remaining = RegExp(
      r'Record (\d+) more',
    ).firstMatch(detail)?.group(1);
    if (remaining == null) {
      return journeyText(
        context,
        'Not enough history yet. Record more task outcomes before options are compared. No personal estimate is shown yet.',
        'Todavía no hay suficiente historial. Registra más resultados de tareas antes de comparar opciones. Todavía no se muestra una estimación personal.',
      );
    }
    final bool one = remaining == '1';
    return journeyText(
      context,
      'Not enough history yet. Record $remaining more task outcome${one ? '' : 's'} before Axiomara compares options. No personal estimate is shown yet.',
      'Todavía no hay suficiente historial. Registra $remaining ${one ? 'resultado más' : 'resultados más'} de tareas antes de que Axiomara compare opciones. Todavía no se muestra una estimación personal.',
    );
  }
  final (String, String)? plain = switch (detail) {
    'Trajectory evidence could not be reconciled. No future conclusion is currently valid.' => (
      'Your records could not be read for this estimate, so none is shown. Try again.',
      'No se pudieron leer tus registros para esta estimación, así que no se muestra ninguna. Inténtalo de nuevo.',
    ),
    'Building a revisioned baseline before comparing future paths.' => (
      'Working out your plan now before comparing options.',
      'Calculando tu plan actual antes de comparar opciones.',
    ),
    'Add a task with an estimate and, when relevant, a goal or deadline before simulating consequences.' => (
      'Add a task with a time estimate (and its goal or due date, if it has one) to see estimates.',
      'Añade una tarea con una estimación de tiempo (y su meta o fecha límite, si la tiene) para ver estimaciones.',
    ),
    'No network interface is available. Using local evidence without network-backed freshness.' => (
      'No network connection. The estimate uses what is on this device.',
      'No hay conexión de red. La estimación usa lo que hay en este dispositivo.',
    ),
    'Using local evidence while network interface availability is checked.' => (
      'The estimate uses what is on this device while the connection is checked.',
      'La estimación usa lo que hay en este dispositivo mientras se comprueba la conexión.',
    ),
    'Future paths are conditional models. Working availability is not configured, so capacity risk, goal dates, and best-fit claims are withheld.' => (
      'Your working hours are not set, so workload risk, goal dates and the recommendation are held back.',
      'No has configurado tu horario de trabajo, así que se omiten el riesgo de carga, las fechas de las metas y la recomendación.',
    ),
    'The scenario comparison is available, but one supporting intelligence source is incomplete.' =>
      (
        'The options are ready, but one supporting source is incomplete.',
        'Las opciones están listas, pero una fuente de apoyo está incompleta.',
      ),
    'Current baseline, Choose a step plan, schedule links, goals, and progress signals are reconciled.' =>
      (
        'Your plan, Schedule, goals and progress are up to date.',
        'Tu plan, tu agenda, tus metas y tu progreso están al día.',
      ),
    _ => null,
  };
  if (plain != null) return journeyText(context, plain.$1, plain.$2);
  if (Localizations.localeOf(context).languageCode != 'es') return detail;
  return switch (status) {
    TrajectoryEngineStatus.loading => 'Calculando tu estimación.',
    TrajectoryEngineStatus.learning =>
      'Aprendiendo tu patrón antes de mostrar una estimación personal.',
    TrajectoryEngineStatus.ready => 'Tus datos están al día.',
    TrajectoryEngineStatus.empty =>
      'Añade una tarea con una estimación de tiempo para ver estimaciones.',
    TrajectoryEngineStatus.partial => 'Hay datos parciales disponibles.',
    TrajectoryEngineStatus.offline =>
      'Se usan datos locales mientras no haya conexión.',
    TrajectoryEngineStatus.error =>
      'No se pudieron leer tus registros para esta estimación.',
  };
}

String _spanishUnobservedEvidenceState(PredictiveEvidenceOrigin origin) =>
    switch (origin) {
      PredictiveEvidenceOrigin.observed => 'registrada',
      PredictiveEvidenceOrigin.estimated => 'estimada; no registrada',
      PredictiveEvidenceOrigin.inferred => 'deducida; no registrada',
      PredictiveEvidenceOrigin.legacy =>
        'basada en datos antiguos; no registrada',
      PredictiveEvidenceOrigin.unavailable => 'sin datos registrados',
    };

String _englishUnobservedEvidenceState(PredictiveEvidenceOrigin origin) =>
    switch (origin) {
      PredictiveEvidenceOrigin.observed => 'recorded',
      PredictiveEvidenceOrigin.estimated => 'estimated; not recorded',
      PredictiveEvidenceOrigin.inferred => 'inferred; not recorded',
      PredictiveEvidenceOrigin.legacy => 'from older data; not recorded',
      PredictiveEvidenceOrigin.unavailable => 'not recorded',
    };

List<String> _trajectoryAssumptionTexts(
  BuildContext context,
  List<String> assumptions,
  List<String> sharedInformationWarnings,
) {
  final pairedConstraints = <String>{
    for (final warning in sharedInformationWarnings)
      if (assumptions.contains(_reportedTrajectoryAssumption(warning)))
        'Person Context constraint: $warning',
  };
  return assumptions
      .where((value) => !pairedConstraints.contains(value))
      .map(
        (value) => _trajectoryAssumptionText(
          context,
          value,
          sharedInformationWarnings,
        ),
      )
      .toList(growable: false);
}

String _reportedTrajectoryAssumption(String warning) =>
    'User-reported Person Context: $warning It constrains this scenario but is not treated as identity or a guaranteed outcome.';

final RegExp _freshCapacityWarning = RegExp(
  r'^Fresh capacity limited this decision to ([0-9]+) minutes\.$',
);

// Only call for warnings matched against the structured baseline list. Task
// labels remain verbatim; the producer-owned framing is localized separately.
String _trajectorySharedInformationWarningText(
  BuildContext context,
  String warning,
) {
  // The forecast applies a "capacity right now" limit to today only (the
  // first day of the range), so the sentence says that in both languages.
  final RegExpMatch? capacity = _freshCapacityWarning.firstMatch(warning);
  if (capacity != null) {
    final String minutes = capacity.group(1)!;
    return journeyText(
      context,
      'Your capacity right now limits today to $minutes minutes. Later days in the range use your usual free time.',
      'Tu capacidad actual limita hoy a $minutes minutos. Los demás días del periodo usan tu tiempo libre habitual.',
    );
  }
  if (Localizations.localeOf(context).languageCode != 'es') return warning;
  final templates = <(RegExp, String Function(String))>[
    (
      RegExp(
        r'^Current priority matched (.+) and may only break a close ranking tie\.$',
      ),
      (labels) =>
          'La prioridad actual coincide con $labels y solo puede desempatar opciones de valoración similar.',
    ),
    (
      RegExp(r'^Explicit boundary excluded (.+) from this decision\.$'),
      (labels) => 'El límite explícito excluyó $labels de esta decisión.',
    ),
    (
      RegExp(r'^Scheduled commitment protected (.+) during conflict checks\.$'),
      (labels) =>
          'El compromiso programado protegió $labels al comprobar conflictos.',
    ),
  ];
  for (final (pattern, render) in templates) {
    final match = pattern.firstMatch(warning);
    if (match != null) return render(match.group(1)!);
  }
  return _trajectoryGeneratedText(context, warning);
}

String _trajectoryAssumptionText(
  BuildContext context,
  String assumption,
  List<String> sharedInformationWarnings,
) {
  for (final String warning in sharedInformationWarnings) {
    if (assumption == _reportedTrajectoryAssumption(warning)) {
      return journeyText(
        context,
        'Information you shared: ${_trajectorySharedInformationWarningText(context, warning)} It limits this estimate but does not define you or promise an outcome.',
        'Información que compartiste: ${_trajectorySharedInformationWarningText(context, warning)} Limita esta estimación, pero no te define ni promete un resultado.',
      );
    }
    if (assumption == 'Person Context constraint: $warning') {
      return journeyText(
        context,
        'Information you shared: ${_trajectorySharedInformationWarningText(context, warning)}',
        'Información que compartiste: ${_trajectorySharedInformationWarningText(context, warning)}',
      );
    }
  }
  // A shared note that is not one of the structured warnings keeps its own
  // words; only the framing around it is reworded.
  final RegExpMatch? reported = _reportedTrajectoryFraming.firstMatch(
    assumption,
  );
  if (reported != null) {
    final String note = reported.group(1)!;
    return journeyText(
      context,
      'Information you shared: $note It limits this estimate but does not define you or promise an outcome.',
      'Información que compartiste: $note Limita esta estimación, pero no te define ni promete un resultado.',
    );
  }
  return _trajectoryGeneratedText(context, assumption);
}

final RegExp _reportedTrajectoryFraming = RegExp(
  r'^User-reported Person Context: (.+) It constrains this scenario but is not treated as identity or a guaranteed outcome\.$',
  dotAll: true,
);

String _trajectoryGeneratedText(BuildContext context, String value) {
  final String? plain = switch (value) {
    // The keep-going option goes by the page's own name for it.
    'Maintain current course' => journeyText(
      context,
      'Keep going as you are',
      'Seguir como vas',
    ),
    'Person context was unavailable at scenario construction, so no personal context was inferred.' =>
      journeyText(
        context,
        'Shared personal information was unavailable, so none was inferred for this estimate.',
        'La información personal compartida no estaba disponible, por lo que no se dedujo para esta estimación.',
      ),
    'The no-context capacity and unscheduled values remain available for comparison.' =>
      journeyText(
        context,
        'Capacity and unscheduled-work estimates without shared personal information remain available for comparison.',
        'Las estimaciones de capacidad y trabajo sin programar calculadas sin información personal compartida siguen disponibles para comparar.',
      ),
    'Energy is a seeded planning estimate, not a user observation.' =>
      journeyText(
        context,
        'Energy is a starting estimate, not something you recorded.',
        'La energía es una estimación inicial, no un dato que hayas registrado.',
      ),
    'Only the declared intervention changes; unmodeled life events remain outside this scenario.' =>
      journeyText(
        context,
        'This estimate changes only the option you chose, not other events in your life.',
        'Esta estimación cambia solo la opción elegida, no otros sucesos de tu vida.',
      ),
    'Person context was available but contained no fresh consented Insights operational signals.' =>
      journeyText(
        context,
        'Shared personal information had no recent details this estimate could use.',
        'La información personal compartida no tenía datos recientes utilizables para esta estimación.',
      ),
    // Risk factors are 0-100 risk scores, not the workload percentage, so
    // they are named as risk scores.
    'Pressure load' => journeyText(
      context,
      'Overall risk score',
      'Puntuación de riesgo general',
    ),
    'Deferral accumulation' => journeyText(
      context,
      'Put-off risk score',
      'Puntuación de riesgo por aplazamientos',
    ),
    'Deadline pressure' => journeyText(
      context,
      'Deadline risk score',
      'Puntuación de riesgo por fechas límite',
    ),
    'Capacity overload' => journeyText(
      context,
      'Free-time risk score',
      'Puntuación de riesgo por tiempo libre',
    ),
    'Sustained pressure raises rollover and recovery risk.' => journeyText(
      context,
      'A lot of work for a long time raises the risk that work rolls over and catching up takes longer.',
      'Mucho trabajo durante mucho tiempo aumenta el riesgo de que el trabajo se acumule y ponerse al día cueste más.',
    ),
    'Current completion and deferral rates remain directionally similar.' =>
      journeyText(
        context,
        'You keep finishing and putting off tasks at about the same rate as now.',
        'Sigues terminando y aplazando tareas a un ritmo parecido al actual.',
      ),
    'Projected XP is informational and is never awarded by this simulation.' =>
      journeyText(
        context,
        'Projected XP is for information only; this estimate never awards it.',
        'Los XP proyectados son solo informativos; esta estimación nunca los concede.',
      ),
    trajectoryAssumedWorkdayAssumption => journeyText(
      context,
      trajectoryAssumedWorkdayAssumption,
      'El tiempo libre se basa en una jornada supuesta porque no hay horario de trabajo configurado.',
    ),
    trajectoryGoalDateAssumption => journeyText(
      context,
      trajectoryGoalDateAssumption,
      'Las fechas de las metas suponen que tu tiempo libre diario se dedica a las tareas pendientes de la meta; otro trabajo puede retrasarlas.',
    ),
    trajectoryUndatedTasksAssumption => journeyText(
      context,
      trajectoryUndatedTasksAssumption,
      'Las tareas sin fecha cuentan en todos los periodos.',
    ),
    _ => null,
  };
  if (plain != null) return plain;
  final bool isSpanish = Localizations.localeOf(context).languageCode == 'es';
  final (String, String)? exact = _plainGeneratedText[value];
  if (exact != null) return isSpanish ? exact.$2 : exact.$1;
  return _plainGeneratedPattern(context, value, isSpanish) ??
      _plainCounts(value, isSpanish) ??
      value;
}

/// The forecast's fixed sentences in plain words: (English, Spanish). The
/// engine and provider strings themselves stay as they are.
const Map<String, (String, String)>
_plainGeneratedText = <String, (String, String)>{
  'Repeated deferrals compound uncertainty in future capacity.': (
    'Putting tasks off again and again makes your later free time harder to predict.',
    'Aplazar tareas una y otra vez hace más difícil prever tu tiempo libre futuro.',
  ),
  'Crossed deadlines reduce slack and can displace other work.': (
    'Missed due dates leave less room and can push other work back.',
    'Las fechas límite superadas dejan menos margen y pueden retrasar otro trabajo.',
  ),
  'Unscheduled work indicates that current commitments do not fit.': (
    'Work without a time in your plan means it does not all fit in your free time.',
    'El trabajo sin hora en tu plan indica que no todo cabe en tu tiempo libre.',
  ),
  'Capacity risk is not scored until working availability is configured.': (
    'This risk is not shown until your working hours are set.',
    'Este riesgo no se muestra hasta que configures tu horario de trabajo.',
  ),
  'No observed availability is configured. Capacity-based risk and goal completion dates are withheld.': (
    'Your working hours are not set, so the free-time risk and goal dates are not shown.',
    'Tu horario de trabajo no está configurado, así que no se muestran el riesgo por tiempo libre ni las fechas de las metas.',
  ),
  'Model this commitment as completed, then compare capacity, risk, goal timing, and progress consequences.':
      (
        'What changes if you finish this task.',
        'Qué cambia si terminas esta tarea.',
      ),
  'Model the declared delay and expose its deadline, capacity, goal, and risk consequences.':
      (
        'What changes if you put this task off.',
        'Qué cambia si aplazas esta tarea.',
      ),
  'Remove this commitment from the active capacity window and compare the resulting tradeoff.':
      (
        'What changes if you take this task out of your plan.',
        'Qué cambia si quitas esta tarea de tu plan.',
      ),
  'Model the selected Choose a step task as completed in its feasible block.': (
    'What changes if you finish the task Choose a step suggests, in the time it found for it.',
    'Qué cambia si terminas la tarea que sugiere Elegir un paso, en el tiempo que encontró para ella.',
  ),
  'Model one day of slippage and its Schedule and goal consequences.': (
    'What changes if this task slips by a day.',
    'Qué cambia si esta tarea se retrasa un día.',
  ),
  'Apply the task-specific deadline/capacity recovery recommendation.': (
    'Catch up on this task first, as suggested.',
    'Ponerte al día primero con esta tarea, como se sugiere.',
  ),
  'Preserve the current plan without a declared intervention.': (
    'Your plan stays as it is.',
    'Tu plan se queda como está.',
  ),
  'Protect the highest-value feasible block.': (
    'Keep time for your most valuable task.',
    'Reservar tiempo para tu tarea más valiosa.',
  ),
  'The protected block is attempted.': (
    'You work in the time kept for it.',
    'Trabajas en el tiempo reservado para ella.',
  ),
  'No progress reward is projected from this intervention alone.': (
    'This option alone earns no progress points.',
    'Esta opción por sí sola no da puntos de progreso.',
  ),
  'The proposed TimeBlocks are accepted and attempted.': (
    'You accept the suggested times and work in them.',
    'Aceptas las horas sugeridas y trabajas en ellas.',
  ),
  'Displaced work is explicitly reconciled instead of silently carried.': (
    'Work that no longer fits is moved on purpose, not left behind.',
    'El trabajo que ya no cabe se mueve a propósito, no se queda atrás.',
  ),
  'The task is completed without creating an unmodeled commitment.': (
    'Finishing it adds no new work.',
    'Terminarla no añade trabajo nuevo.',
  ),
  'The commitment is completed without creating an unmodeled obligation.': (
    'Finishing it adds no new work.',
    'Terminarla no añade trabajo nuevo.',
  ),
  'The delayed work remains active and consumes later capacity.': (
    'The work you put off still needs time later.',
    'El trabajo aplazado sigue necesitando tiempo más adelante.',
  ),
  'The delayed commitment remains active and consumes later capacity.': (
    'The work you put off still needs time later.',
    'El trabajo aplazado sigue necesitando tiempo más adelante.',
  ),
  'The first verifiable recovery checkpoint is completed.': (
    'You finish the first step of catching up.',
    'Terminas el primer paso para ponerte al día.',
  ),
  'The removed commitment is optional or safely deferred with consent.': (
    'The task you take out is optional, or you have agreed to move it.',
    'La tarea que quitas es opcional o has aceptado moverla.',
  ),
  'The commitment is optional or can be deferred with informed consent.': (
    'The task is optional, or you have agreed to move it.',
    'La tarea es opcional o has aceptado moverla.',
  ),
  'Projected progress effects remain informational until an outcome is recorded on Schedule.': (
    'Progress shown here is only an estimate until you record what happened.',
    'El progreso que se muestra aquí es solo una estimación hasta que registres lo que pasó.',
  ),
  'No replacement work is assumed unless it already exists in the baseline.': (
    'No new work is assumed unless it is already in your plan.',
    'No se supone trabajo nuevo salvo que ya esté en tu plan.',
  ),
  'The simulation does not delete or mutate the actual task.': (
    'Your real task is not deleted or changed.',
    'Tu tarea real no se elimina ni se cambia.',
  ),
  'Projected completion remains inside the recorded target date.': (
    'It could be done by the target date.',
    'Podría estar terminada para la fecha objetivo.',
  ),
  // Task follow-through (the prediction provider's own words).
  'Higher observed follow-through': (
    'You usually finish tasks like this',
    'Sueles terminar tareas como esta',
  ),
  'Lower observed follow-through': (
    'You often leave tasks like this unfinished',
    'A menudo dejas sin terminar tareas como esta',
  ),
  'Mixed observed follow-through': (
    'You finish tasks like this about half the time',
    'Terminas tareas como esta más o menos la mitad de las veces',
  ),
  'No exact task history exists, so this estimate uses all recorded completed and skipped task outcomes.': (
    'There is no history for this task yet, so this uses all the tasks you finished or skipped.',
    'Aún no hay historial de esta tarea, así que se usan todas las tareas que terminaste u omitiste.',
  ),
  'This estimate uses recorded completed and skipped outcomes for this task title.':
      (
        'This uses the times you finished or skipped a task with this title.',
        'Se usan las veces que terminaste u omitiste una tarea con este título.',
      ),
  'No prior execution history is available for this task yet.': (
    'There is no history for this task yet.',
    'Aún no hay historial de esta tarea.',
  ),
  // Titles that keep their English words but need Spanish.
  'Keep the suggested plan': (
    'Keep the suggested plan',
    'Proteger el camino de Elegir un paso',
  ),
  'Delay the milestone': ('Delay the milestone', 'Aplazar el hito'),
  'Use the suggested option in this estimate': (
    'Use the suggested option in this estimate',
    'Aplicar la recomendación de Elegir un paso',
  ),
  'Apply Choose a step recommendation': (
    'Apply Choose a step recommendation',
    'Aplicar la recomendación de Elegir un paso',
  ),
  'Reduce lower-priority scope': (
    'Reduce lower-priority scope',
    'Reducir el alcance de menor prioridad',
  ),
};

/// Generated sentences that carry a task title or a figure.
String? _plainGeneratedPattern(
  BuildContext context,
  String value,
  bool isSpanish,
) {
  // "<option> changes <subject> against baseline <revision>. Projected risk
  // is <band>; <Schedule effect>": the Schedule effect has its own line, so
  // only the comparison and the risk are said here.
  final RegExpMatch? explanation = RegExp(
    r'^(.+) changes (.+) against baseline \S+\. Projected risk is (\w+); .*$',
    dotAll: true,
  ).firstMatch(value);
  if (explanation != null) {
    final String subject = explanation.group(2)!;
    final bool whole = subject == 'the current portfolio';
    final String band = switch (explanation.group(3)) {
      'low' => isSpanish ? 'bajo' : 'low',
      'watch' => isSpanish ? 'a vigilar' : 'worth watching',
      'elevated' => isSpanish ? 'elevado' : 'raised',
      'critical' => isSpanish ? 'alto' : 'high',
      _ => isSpanish ? 'sin calcular' : 'not worked out',
    };
    return isSpanish
        ? 'En comparación con tu plan guardado, esta opción afecta a ${whole ? 'tu plan en conjunto' : subject}. Riesgo estimado: $band.'
        : 'Compared with your saved plan, this option affects ${whole ? 'your plan as a whole' : subject}. Estimated risk: $band.';
  }
  String? between(String prefix, String suffix) =>
      value.startsWith(prefix) &&
          value.endsWith(suffix) &&
          value.length > prefix.length + suffix.length
      ? value.substring(prefix.length, value.length - suffix.length)
      : null;
  final String? removed = between(
    'Remove ',
    ' from the active capacity window.',
  );
  if (removed != null) {
    return isSpanish
        ? 'Qué cambia si quitas $removed de tu plan.'
        : 'What changes if you take $removed out of your plan.';
  }
  final String? protected = between(
    'Protect ',
    ' and use the feasible plan as the active schedule.',
  );
  if (protected != null) {
    return isSpanish
        ? 'Reservar tiempo para $protected y seguir el horario sugerido.'
        : 'Keep time for $protected and follow the suggested schedule.';
  }
  if (value.startsWith(
    'Estimate what happens if you finish the selected task',
  )) {
    return isSpanish ? 'Qué cambia si terminas la tarea seleccionada.' : value;
  }
  if (!isSpanish) return null;
  final String? completed = between('Complete ', '');
  if (value.startsWith('Complete ') && completed != null) {
    return 'Completar $completed';
  }
  final String? delayed = between('Delay ', ' by one day');
  if (delayed != null) return 'Aplazar $delayed un día';
  if (value.startsWith('Recover ')) {
    return 'Recuperar ${value.substring('Recover '.length)}';
  }
  if (value.startsWith('My scenario: complete ')) {
    return 'Mi escenario: completar ${value.substring('My scenario: complete '.length)}';
  }
  if (value.startsWith('My scenario: remove ')) {
    return 'Mi escenario: quitar ${value.substring('My scenario: remove '.length)}';
  }
  final RegExpMatch? delay = RegExp(
    r'^My scenario: delay (.+) (\d+) days?$',
  ).firstMatch(value);
  if (delay != null) {
    final String days = delay.group(2)!;
    return 'Mi escenario: aplazar ${delay.group(1)!} $days ${days == '1' ? 'día' : 'días'}';
  }
  return null;
}

/// Generated sentences with counts, in plain words with the right singular
/// or plural (the engine writes "block(s)").
String? _plainCounts(String value, bool es) {
  String blocks(int n) => es
      ? (n == 0
            ? 'ningún bloque planificado'
            : n == 1
            ? '1 bloque planificado'
            : '$n bloques planificados')
      : (n == 0
            ? 'no planned blocks'
            : n == 1
            ? '1 planned block'
            : '$n planned blocks');

  RegExpMatch? match(String pattern) => RegExp(pattern).firstMatch(value);
  int at(RegExpMatch m, int group) => int.parse(m.group(group)!);

  final RegExpMatch? planner = match(
    r'^(\d+) Choose a step block\(s\) are projected; (\d+) commitment\(s\) remain displaced\.$',
  );
  if (planner != null) {
    final int moved = at(planner, 2);
    return es
        ? 'Elegir un paso planifica ${blocks(at(planner, 1))}; ${moved == 0
              ? 'ninguna tarea queda desplazada'
              : moved == 1
              ? '1 tarea queda desplazada'
              : '$moved tareas quedan desplazadas'}.'
        : 'Choose a step plans ${blocks(at(planner, 1))}; ${moved == 0
              ? 'no task is pushed out'
              : moved == 1
              ? '1 task is pushed out'
              : '$moved tasks are pushed out'}.';
  }
  final RegExpMatch? delayed = match(
    r'^(\d+) existing block\(s\) are affected; (\d+) deadline crossing\(s\) are projected\.$',
  );
  if (delayed != null) {
    final int due = at(delayed, 2);
    final int n = at(delayed, 1);
    return es
        ? '${n == 0
              ? 'Ningún bloque planificado se ve afectado'
              : n == 1
              ? '1 bloque planificado se ve afectado'
              : '$n bloques planificados se ven afectados'}; ${due == 0
              ? 'no se pasa ninguna fecha límite'
              : due == 1
              ? 'podría pasarse 1 fecha límite'
              : 'podrían pasarse $due fechas límite'}.'
        : '${n == 0
              ? 'No planned block is affected'
              : n == 1
              ? '1 planned block is affected'
              : '$n planned blocks are affected'}; ${due == 0
              ? 'no due date is missed'
              : due == 1
              ? '1 due date could be missed'
              : '$due due dates could be missed'}.';
  }
  final RegExpMatch? freed = match(
    r'^(\d+) linked block\(s\) can (?:close after the simulated completion|be removed from active load)\.$',
  );
  if (freed != null) {
    final int n = at(freed, 1);
    return es
        ? (n == 0
              ? 'No se libera ningún bloque planificado.'
              : n == 1
              ? 'Se libera 1 bloque planificado.'
              : 'Se liberan $n bloques planificados.')
        : (n == 0
              ? 'No planned block is freed.'
              : n == 1
              ? '1 planned block is freed.'
              : '$n planned blocks are freed.');
  }
  final RegExpMatch? affected = match(
    r'^(\d+) linked Schedule block\(s\) are affected\.$',
  );
  if (affected != null) {
    final int n = at(affected, 1);
    return es
        ? (n == 0
              ? 'No cambia ningún bloque planificado.'
              : n == 1
              ? 'Cambia 1 bloque planificado.'
              : 'Cambian $n bloques planificados.')
        : (n == 0
              ? 'No planned block changes.'
              : n == 1
              ? '1 planned block changes.'
              : '$n planned blocks change.');
  }
  final RegExpMatch? late = match(
    r'^Projected completion crosses the target by about (\d+) day\(s\)\.$',
  );
  if (late != null) {
    final int n = at(late, 1);
    return es
        ? 'Podría terminarse unos ${n == 1 ? '1 día' : '$n días'} después de la fecha objetivo.'
        : 'It could be done about ${n == 1 ? '1 day' : '$n days'} after the target date.';
  }
  final RegExpMatch? left = match(
    r'^(\d+) remaining linked minutes; no target date is recorded\.$',
  );
  if (left != null) {
    return es
        ? 'Quedan ${left.group(1)} minutos de trabajo de esta meta; no tiene fecha objetivo.'
        : '${left.group(1)} minutes of this goal\'s work left; it has no target date.';
  }
  final RegExpMatch? xp = match(
    r'^Up to (\d+) XP is informationally projected if the action is actually completed; current streak protection is (supported|not supported)\.$',
  );
  if (xp != null) {
    final bool streak = xp.group(2) == 'supported';
    return es
        ? 'Si de verdad lo haces, podría darte hasta ${xp.group(1)} XP${streak ? ' y mantener tu racha' : '; no mantiene tu racha'}.'
        : 'If you really do it, it could earn up to ${xp.group(1)} XP${streak ? ' and keep your streak going' : '; it does not keep your streak going'}.';
  }
  return null;
}

String _trajectoryConfidenceLabel(
  BuildContext context,
  PredictiveConfidenceBand band,
) {
  final bool isSpanish = Localizations.localeOf(context).languageCode == 'es';
  return switch (band) {
    PredictiveConfidenceBand.high => isSpanish ? 'alta' : 'high',
    PredictiveConfidenceBand.moderate => isSpanish ? 'moderada' : 'moderate',
    PredictiveConfidenceBand.low => isSpanish ? 'baja' : 'low',
    PredictiveConfidenceBand.insufficientEvidence =>
      isSpanish ? 'insuficiente' : 'insufficient',
  };
}

/// Workload band for a whole percent (thresholds 50 and 80, as before).
String _workloadBand(BuildContext context, int load) => load >= 80
    ? journeyText(context, 'Heavy', 'Pesada')
    : load >= 50
    ? journeyText(context, 'Busy', 'Intensa')
    : journeyText(context, 'Light', 'Ligera');

/// Pace band for the model's pace score (same cut-offs as before).
String _paceBand(BuildContext context, int momentum) =>
    switch (trajectoryMomentumBand(momentum)) {
      'STRONG' => journeyText(context, 'Strong', 'Fuerte'),
      'STEADY' => journeyText(context, 'Steady', 'Estable'),
      _ => journeyText(context, 'Building', 'En aumento'),
    };

/// "5 points higher" / "5 points lower" / "no change", for one change.
String _changeWords(BuildContext context, int delta) {
  if (delta == 0) return journeyText(context, 'no change', 'sin cambio');
  final int size = delta.abs();
  final bool one = size == 1;
  return delta > 0
      ? journeyText(
          context,
          '$size point${one ? '' : 's'} higher',
          '$size punto${one ? '' : 's'} más',
        )
      : journeyText(
          context,
          '$size point${one ? '' : 's'} lower',
          '$size punto${one ? '' : 's'} menos',
        );
}
