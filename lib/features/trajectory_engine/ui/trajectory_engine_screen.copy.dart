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
    'Pressure load' => journeyText(context, 'Workload', 'Carga de trabajo'),
    'Deferral accumulation' => journeyText(
      context,
      'Put-off tasks piling up',
      'Tareas aplazadas que se acumulan',
    ),
    'Deadline pressure' => journeyText(
      context,
      'Workload from deadlines',
      'Carga por fechas límite',
    ),
    'Capacity overload' => journeyText(
      context,
      'Workload over your free time',
      'Carga por encima de tu tiempo libre',
    ),
    'Sustained pressure raises rollover and recovery risk.' => journeyText(
      context,
      'A heavy workload over time raises the risk that work rolls over and recovery takes longer.',
      'Una carga alta durante mucho tiempo aumenta el riesgo de que el trabajo se acumule y la recuperación tarde más.',
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
  value = value.replaceAll(
    RegExp(r' against baseline \S+\. '),
    journeyText(
      context,
      ' compared with your saved plan. ',
      ' en comparación con tu plan guardado. ',
    ),
  );
  if (Localizations.localeOf(context).languageCode != 'es') return value;
  const exact = <String, String>{
    'Repeated deferrals compound uncertainty in future capacity.':
        'Los aplazamientos repetidos aumentan la incertidumbre sobre la capacidad futura.',
    'Crossed deadlines reduce slack and can displace other work.':
        'Las fechas límite incumplidas reducen el margen y pueden desplazar otro trabajo.',
    'Unscheduled work indicates that current commitments do not fit.':
        'El trabajo sin programar indica que los compromisos actuales no caben.',
    'Capacity risk is not scored until working availability is configured.':
        'El riesgo de capacidad no se calcula hasta configurar la disponibilidad.',
    'No observed availability is configured. Capacity-based risk and goal completion dates are withheld.':
        'No hay disponibilidad registrada. Se omiten el riesgo de capacidad y las fechas de finalización.',
    'Model this commitment as completed, then compare capacity, risk, goal timing, and progress consequences.':
        'Modelar este compromiso como completado y comparar sus consecuencias en capacidad, riesgo, fechas de metas y progreso.',
    'No progress reward is projected from this intervention alone.':
        'Esta intervención por sí sola no proyecta una recompensa de progreso.',
    'Keep the suggested plan': 'Proteger el camino de Elegir un paso',
    'Protect the highest-value feasible block.':
        'Proteger el bloque viable de mayor valor.',
    'The protected block is attempted.':
        'Se intenta completar el bloque protegido.',
    'Delay the milestone': 'Aplazar el hito',
    'Use the suggested option in this estimate':
        'Aplicar la recomendación de Elegir un paso',
    'Apply Choose a step recommendation':
        'Aplicar la recomendación de Elegir un paso',
    'Model the selected Choose a step task as completed in its feasible block.':
        'Modelar la tarea seleccionada de Elegir un paso como completada en su bloque viable.',
    'Reduce lower-priority scope': 'Reducir el alcance de menor prioridad',
    'Preserve the current plan without a declared intervention.':
        'Conservar el plan actual sin una intervención declarada.',
    'The proposed TimeBlocks are accepted and attempted.':
        'Los bloques de tiempo propuestos se aceptan y se intentan.',
    'Displaced work is explicitly reconciled instead of silently carried.':
        'El trabajo desplazado se concilia de forma explícita en lugar de arrastrarse en silencio.',
    'The task is completed without creating an unmodeled commitment.':
        'La tarea se completa sin crear un compromiso no modelado.',
    'The delayed work remains active and consumes later capacity.':
        'El trabajo aplazado sigue activo y consume capacidad posterior.',
    'The first verifiable recovery checkpoint is completed.':
        'Se completa el primer punto de recuperación verificable.',
    'The removed commitment is optional or safely deferred with consent.':
        'El compromiso eliminado es opcional o puede aplazarse de forma segura con consentimiento.',
    'The commitment is completed without creating an unmodeled obligation.':
        'El compromiso se completa sin crear una obligación no modelada.',
    'Projected progress effects remain informational until an outcome is recorded on Schedule.':
        'Los efectos proyectados en el progreso son informativos hasta registrar un resultado en la agenda.',
    'The delayed commitment remains active and consumes later capacity.':
        'El compromiso aplazado sigue activo y consume capacidad posterior.',
    'No replacement work is assumed unless it already exists in the baseline.':
        'No se supone trabajo de reemplazo salvo que ya exista en tu plan actual.',
    'The commitment is optional or can be deferred with informed consent.':
        'El compromiso es opcional o puede aplazarse con consentimiento informado.',
    'The simulation does not delete or mutate the actual task.':
        'La simulación no elimina ni modifica la tarea real.',
    'Remove this commitment from the active capacity window and compare the resulting tradeoff.':
        'Quitar este compromiso de la ventana de capacidad activa y comparar la compensación resultante.',
  };
  final translated = exact[value];
  if (translated != null) return translated;
  if (value.startsWith('Complete ')) {
    return 'Completar ${value.substring('Complete '.length)}';
  }
  if (value.startsWith('Delay ') && value.endsWith(' by one day')) {
    return 'Aplazar ${value.substring('Delay '.length, value.length - ' by one day'.length)} un día';
  }
  if (value.startsWith('Recover ')) {
    return 'Recuperar ${value.substring('Recover '.length)}';
  }
  if (value.startsWith('Protect ') &&
      value.endsWith(' and use the feasible plan as the active schedule.')) {
    final String subject = value.substring(
      'Protect '.length,
      value.length -
          ' and use the feasible plan as the active schedule.'.length,
    );
    return 'Proteger $subject y usar el plan viable como horario activo.';
  }
  if (value.startsWith(
    'Estimate what happens if you finish the selected task',
  )) {
    return 'Modelar la tarea seleccionada de Elegir un paso como completada en su bloque viable.';
  }
  if (value.startsWith('Model one day of slippage')) {
    return 'Modelar un día de retraso y sus consecuencias en la agenda y las metas.';
  }
  if (value.startsWith(
    'Apply the task-specific deadline/capacity recovery recommendation.',
  )) {
    return 'Aplicar la recomendación específica de recuperación de fecha límite y capacidad.';
  }
  if (value.startsWith('Remove ') &&
      value.endsWith(' from the active capacity window.')) {
    final String subject = value.substring(
      'Remove '.length,
      value.length - ' from the active capacity window.'.length,
    );
    return 'Quitar $subject de la ventana de capacidad activa.';
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
  return value
      .replaceAll(
        'scheduled block(s) are estimated',
        'bloque(s) de Elegir un paso se proyectan',
      )
      .replaceAll(
        'commitment(s) remain displaced',
        'compromiso(s) permanecen desplazados',
      )
      .replaceAll(
        'existing block(s) are affected',
        'bloque(s) existentes se ven afectados',
      )
      .replaceAll(
        'deadline crossing(s) are projected',
        'cruce(s) de fecha límite se proyectan',
      )
      .replaceAll(
        'linked block(s) can close after the simulated completion',
        'bloque(s) vinculados pueden cerrarse tras completar la simulación',
      )
      .replaceAll(
        'linked block(s) can be removed from active load',
        'bloque(s) vinculados pueden salir de la carga activa',
      )
      .replaceAll(
        'linked Schedule block(s) are affected',
        'bloque(s) vinculados de la agenda se ven afectados',
      )
      .replaceAll(
        'remaining linked minutes; no target date is recorded',
        'minutos vinculados restantes; no hay fecha objetivo',
      )
      .replaceAll(
        'Projected completion crosses the target by about',
        'La finalización proyectada supera el objetivo por unos',
      )
      .replaceAll('day(s)', 'día(s)')
      .replaceAll(
        'Projected completion remains inside the recorded target date.',
        'La finalización proyectada queda dentro de la fecha objetivo registrada.',
      )
      .replaceAll('Projected risk is', 'El riesgo proyectado es')
      .replaceAll('against baseline', 'frente a tu plan actual')
      .replaceAll('changes', 'cambia');
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
