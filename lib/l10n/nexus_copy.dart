import 'package:fantastic_guacamole/core/utils/date_time_formats.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:flutter/material.dart';

/// Presentation copy only. Stored names, decision identity and numeric
/// evidence stay unchanged when the interface language changes.
class NexusCopy {
  const NexusCopy(this.isSpanish);

  factory NexusCopy.of(BuildContext context) =>
      NexusCopy(ChronoSparkLocalizations.of(context).isSpanish);

  final bool isSpanish;

  String get productName => 'AXIOMARA';
  String get nexusTitle => isSpanish ? 'Hoy' : 'Today';
  String get tagline => isSpanish
      ? 'Tómate un momento. Elige qué te ayudaría ahora.'
      : 'Take a moment. Choose what would help right now.';
  String get logicCore => isSpanish ? 'Espacio para pensar' : 'Space to think';
  String get openNotifications =>
      isSpanish ? 'Abrir notificaciones' : 'Open notifications';
  String get logOut => isSpanish ? 'Cerrar sesión' : 'Log out';
  String get logOutFailed => isSpanish
      ? 'No se pudo cerrar la sesión. Inténtalo de nuevo.'
      : 'Could not log out. Please try again.';
  String get context => isSpanish ? 'CONTEXTO' : 'CONTEXT';
  String profileStatus(String name, int level, int streak) => isSpanish
      ? (name.isEmpty ? 'Bienvenido' : name)
      : (name.isEmpty ? 'Welcome' : name);

  String get decisionLoop => isSpanish
      ? '¿Por dónde quieres empezar?'
      : 'Where would you like to start?';
  String get decisionLoopSubtitle => isSpanish
      ? 'Pregunta sobre un plan, elige un pequeño paso o guarda una tarea.'
      : 'Ask about a plan, choose one small step, or save a task.';
  String get buildReality => isSpanish ? 'Añadir una tarea' : 'Add a task';
  String get morePlanningTools => isSpanish ? 'Más herramientas' : 'More tools';
  String get resolveNow =>
      isSpanish ? 'Elegir un pequeño paso' : 'Choose a small step';
  String get interrogate => 'Chat';
  String get compareFutures =>
      isSpanish ? 'Comparar opciones' : 'Compare options';
  String get scheduleEyebrow => isSpanish ? 'AGENDA' : 'SCHEDULE';
  String get reviewTruth =>
      isSpanish ? 'Tareas e historial' : 'Tasks and history';
  String get loopControlNote => isSpanish
      ? 'Tú eliges qué guardar o cambiar. Puedes revisar los resultados registrados.'
      : 'You choose what to save or change. You can review recorded results.';
  String get builtForReality =>
      isSpanish ? 'CREADO PARA LA VIDA REAL' : 'BUILT FOR REAL LIFE';
  List<String> get realLifeSituations => isSpanish
      ? const <String>[
          'Una reunión cambió. ¿Qué compromiso se rompe primero?',
          'Mi energía cayó. ¿Qué todavía puedo terminar bien?',
          'Si aplazo la compra hasta las 6, ¿qué entra en conflicto?',
        ]
      : const <String>[
          'A meeting moved. Which commitment breaks first?',
          'My energy crashed. What can I still finish well?',
          'If I delay the store until 6, what conflicts?',
        ];

  String get energy => isSpanish ? 'ENERGÍA' : 'ENERGY';
  String get clarity => isSpanish ? 'CLARIDAD' : 'CLARITY';
  String get momentum => isSpanish ? 'IMPULSO' : 'MOMENTUM';
  String get unmeasured => isSpanish ? 'SIN MEDIR' : 'UNMEASURED';
  String get unchecked => isSpanish ? 'SIN REGISTRAR' : 'NOT CHECKED';
  String get energyHint => isSpanish
      ? 'Registra tu energía actual'
      : 'Check in with your current energy';
  String get clarityHint => isSpanish
      ? 'Estimación basada en tu cansancio. Toca para registrarlo'
      : 'Estimate from your fatigue report. Tap to check in';
  String get momentumHint => isSpanish
      ? 'Abre Perspectivas para revisar esta estimación'
      : 'Open Insights to review this estimate';
  String momentumValue(String value) => !isSpanish
      ? value
      : switch (value) {
          'UPDATING' => 'ACTUALIZANDO',
          'UNAVAILABLE' => 'NO DISPONIBLE',
          'LEARNING' => 'APRENDIENDO',
          'NO PLAN' => 'SIN PLAN',
          'STRONG' => 'FUERTE',
          'STEADY' => 'ESTABLE',
          'BUILDING' => 'CRECIENDO',
          _ => value,
        };
  String vitalsSummary({
    required int? energyPercent,
    required int? clarityPercent,
    required String momentumLabel,
  }) => isSpanish
      ? '${energyPercent == null ? 'Energía sin medir' : 'Energía $energyPercent por ciento'}. '
            '${clarityPercent == null ? 'Claridad sin registrar' : 'Claridad estimada $clarityPercent por ciento, basada en el cansancio indicado'}. '
            'Impulso ${momentumValue(momentumLabel)}.'
      : '${energyPercent == null ? 'Energy unmeasured' : 'Energy $energyPercent percent'}. '
            '${clarityPercent == null ? 'Clarity not checked' : 'Estimated clarity $clarityPercent percent, based on reported fatigue'}. '
            'Momentum $momentumLabel.';

  String get currentDecision =>
      isSpanish ? 'Próximo paso sugerido' : 'Suggested next step';
  String get nextMove => isSpanish
      ? 'Revísalo, cámbialo o déjalo para después.'
      : 'Review it, change it, or leave it for later.';
  String get buildNextStep =>
      isSpanish ? 'Define un próximo paso claro' : 'Build one clear next step';
  String get addTaskReason => isSpanish
      ? 'Guarda una tarea en Añadir algo para recibir una sugerencia basada en tus planes.'
      : 'Save a task in Add something to get a suggestion based on your plans.';
  String get scheduledReason => isSpanish
      ? 'Esta tarea programada es el compromiso concreto más próximo.'
      : 'This scheduled task is the nearest concrete commitment.';
  String workOn(String taskTitle) =>
      isSpanish ? 'Trabaja en: $taskTitle' : 'Work on: $taskTitle';
  String systemAction(String value) {
    if (!isSpanish) {
      return switch (value) {
        'Capture one actionable task in Creator.' =>
          'Save one task in Add something.',
        'Reconcile unscheduled work in Smart Planner.' =>
          'Review unscheduled work in Choose a step.',
        _ => value,
      };
    }
    const String workPrefix = 'Work on: ';
    if (value.startsWith(workPrefix)) {
      return 'Trabaja en: ${value.substring(workPrefix.length)}';
    }
    return switch (value) {
      'Take a short recovery break before choosing more work.' =>
        'Toma un breve descanso de recuperación antes de elegir más trabajo.',
      'Capture one actionable task in Creator.' ||
      'Save one task in Add something.' =>
        'Registra una tarea realizable en Añadir algo.',
      'Reconcile unscheduled work in Smart Planner.' ||
      'Review unscheduled work in Choose a step.' =>
        'Concilia el trabajo no programado en Elegir un paso.',
      _ => value,
    };
  }

  String systemRationale(String value) => !isSpanish
      ? value
      : switch (value) {
          'It converts the strongest available signal into measurable forward movement.' =>
            'Convierte la señal más sólida disponible en un avance medible.',
          'It protects the highest-ranked commitment while the current plan exceeds modeled capacity.' =>
            'Protege el compromiso prioritario cuando el plan supera la capacidad estimada.',
          'It reduces current schedule risk and prevents overdue pressure from compounding.' =>
            'Reduce el riesgo actual del calendario y evita que se acumule la presión de los retrasos.',
          _ => value,
        };
  String decisionStatus(String value) => !isSpanish
      ? value
      : switch (value) {
          'LINKING' => 'CONECTANDO',
          'READY' => 'LISTO',
          'PARTIAL' => 'PARCIAL',
          'OFFLINE' => 'SIN CONEXIÓN',
          'RECOVERY NEEDED' => 'REQUIERE RECUPERACIÓN',
          _ => value,
        };
  String whyChanged(String explanation) => isSpanish
      ? 'Por qué cambió: $explanation'
      : 'Why this changed: $explanation';
  String get ignoreContext => isSpanish
      ? 'Ignorar este contexto por ahora'
      : 'Ignore this context for now';
  String get reviewSuggestion =>
      isSpanish ? 'Revisar antes de actuar' : 'Review before acting';
  String get evidence => isSpanish ? 'SEÑAL' : 'SIGNAL';
  String evidenceSummary({
    required int evidenceCount,
    required int freshCount,
    required int sourceCount,
  }) => isSpanish
      ? '$freshCount de $evidenceCount evidencias vigentes · $sourceCount fuentes vinculadas'
      : '$freshCount of $evidenceCount evidence items fresh · $sourceCount linked sources';
  String get uncertainty => isSpanish ? 'INCERTIDUMBRE' : 'UNCERTAINTY';
  String uncertaintySummary({
    required int assumptionCount,
    required int warningCount,
    required bool expired,
  }) {
    if (isSpanish) {
      return '${expired ? 'Decisión vencida' : 'Decisión vigente'} · $assumptionCount supuestos · $warningCount advertencias';
    }
    return '${expired ? 'Decision expired' : 'Decision current'} · $assumptionCount assumptions · $warningCount warnings';
  }

  String get control => isSpanish ? 'CONTROL' : 'CONTROL';
  String controlSummary({
    required bool requiresConfirmation,
    required bool reversible,
  }) => isSpanish
      ? '${requiresConfirmation ? 'Requiere confirmación' : 'Revisión iniciada por ti'} · ${reversible ? 'Acción reversible' : 'Revisa el impacto antes de continuar'}'
      : '${requiresConfirmation ? 'Confirmation required' : 'You initiate the action'} · ${reversible ? 'Reversible action' : 'Review impact before continuing'}';
  String delayed(String consequence) => isSpanish
      ? 'SI ESPERAS: ${systemConsequence(consequence)}'
      : 'IF DELAYED: $consequence';
  String systemConsequence(String value) => !isSpanish
      ? value
      : switch (value) {
          'Waiting leaves the current priority unresolved and makes your next step less clear.' =>
            'La prioridad actual queda sin resolver y el siguiente paso será menos claro.',
          'Waiting can increase rollover pressure and reduce schedule flexibility.' =>
            'Esperar puede aumentar la presión acumulada y reducir la flexibilidad del calendario.',
          _ when value.startsWith('Without reducing or moving work, ') =>
            value
                .replaceFirst(
                  'Without reducing or moving work, ',
                  'Sin reducir ni mover trabajo, ',
                )
                .replaceFirst(
                  ' minutes remain outside available capacity.',
                  ' minutos quedan fuera de la capacidad disponible.',
                ),
          _ => value,
        };
  String get suggestionUnavailable => isSpanish
      ? 'No se pudo cargar una sugerencia de tus planes guardados. Reintenta.'
      : 'We could not load a suggestion from your saved plans. Try again.';
  String get retry => isSpanish ? 'Reintentar' : 'Retry';
  String get priorities =>
      isSpanish ? 'Tus elementos guardados' : 'Your saved items';
  String get prioritiesSubtitle =>
      isSpanish ? 'Meta · tarea · nota' : 'Goal · task · note';
  String get goal => isSpanish ? 'META' : 'GOAL';
  String get task => isSpanish ? 'TAREA' : 'TASK';
  String get note => isSpanish ? 'NOTA' : 'NOTE';
  String open(String label) => isSpanish ? 'Abrir $label' : 'Open $label';
  String get noGoal => isSpanish ? 'No hay una meta activa' : 'No active goal';
  String get createGoal => isSpanish
      ? 'Crea una meta para vincular el trabajo de hoy con un resultado.'
      : 'Create a goal to connect today’s work to an outcome.';
  String get noTask => isSpanish ? 'No hay una tarea activa' : 'No active task';
  String get createTask => isSpanish
      ? 'Crea una tarea y prográmala cuando estés listo.'
      : 'Create a task and schedule it when you are ready.';
  String get loadingNote => isSpanish ? 'Cargando nota…' : 'Loading note…';
  String get noNote => isSpanish ? 'No hay una nota actual' : 'No current note';
  String get createNote => isSpanish
      ? 'Guarda contexto útil sin convertirlo en otra tarea.'
      : 'Capture useful context without turning it into another task.';
  String get activeGoal => isSpanish ? 'Meta activa' : 'Active goal';
  String goalTarget(String date) =>
      isSpanish ? 'Fecha objetivo: $date' : 'Target $date';
  String taskPriority(int priority) => isSpanish
      ? 'Prioridad $priority · sin programar'
      : 'Priority $priority · not scheduled';
  String updated(String date) =>
      isSpanish ? 'Actualizada: $date' : 'Updated $date';

  String get energyCheckIn =>
      isSpanish ? 'Registro de energía' : 'Energy check-in';
  String get clarityCheckIn =>
      isSpanish ? 'Registro de claridad' : 'Clarity check-in';
  String get energyQuestion => isSpanish
      ? '¿Cuánta energía tienes ahora?'
      : 'How much energy do you have right now?';
  String get fatigueQuestion => isSpanish
      ? '¿Cuánto cansancio sientes ahora? La claridad se estima restando a 100% el cansancio que indicas; no es una evaluación cognitiva.'
      : 'How fatigued do you feel right now? Clarity is an estimate of 100% minus your reported fatigue, not a cognitive assessment.';
  String get checkInDisclosure => isSpanish
      ? 'Opcional. Se guarda en este dispositivo y se usa para planificar durante un máximo de dos horas, incluso si vuelves a abrir la aplicación. Puedes borrarlo cuando quieras.'
      : 'Optional. Saved on this device and used for planning for up to two hours, including after you reopen the app. You can clear it at any time.';
  String get notChecked => isSpanish ? 'Sin registrar' : 'Not checked';
  String reportLabel(bool isEnergy) => isEnergy
      ? (isSpanish ? 'Energía' : 'Energy')
      : (isSpanish ? 'Cansancio' : 'Fatigue');
  String sliderValue(bool isEnergy, int percent) =>
      '${reportLabel(isEnergy)} $percent ${isSpanish ? 'por ciento' : 'percent'}';
  String get accountChanged => isSpanish
      ? 'Tu cuenta cambió. Cierra este registro y vuelve a abrirlo.'
      : 'Your account changed. Close this check-in and reopen it.';
  String get cancel => isSpanish ? 'Cancelar' : 'Cancel';
  String get clear => isSpanish ? 'Borrar' : 'Clear';
  String get save => isSpanish ? 'Guardar' : 'Save';

  String get learningChanged => isSpanish
      ? 'Qué cambió con tu opinión'
      : 'What changed after your feedback';
  String get correctLearning =>
      isSpanish ? 'Corregir esta opinión' : 'Correct this feedback';
  String get helped => isSpanish ? 'Esto ayudó' : 'This helped';
  String get didNotHelp => isSpanish ? 'Esto no ayudó' : 'This did not help';
  String learningSummary(
    String summary,
    String kind,
    double before,
    double after,
  ) {
    if (!isSpanish) return summary;
    final outcome = switch (kind) {
      'shown' => 'mostrado',
      'accepted' => 'aceptado',
      'rejected' => 'rechazado',
      'corrected' => 'corregido',
      'completed' => 'completado',
      'skipped' => 'omitido',
      'deferred' => 'aplazado',
      _ => null,
    };
    if (outcome == null) return summary;
    if (before == after &&
        summary ==
            'The $kind outcome was recorded; ranking weights did not change.') {
      return 'Se registró el resultado $outcome; los pesos de prioridad no cambiaron.';
    }
    final from = (before * 100).round();
    final to = (after * 100).round();
    final direction = after > before ? 'increased' : 'decreased';
    if (summary ==
        "This task's learned fit $direction from $from% to $to% after the $kind outcome.") {
      return 'La afinidad aprendida de esta tarea ${after > before ? 'aumentó' : 'disminuyó'} de $from% a $to% tras el resultado $outcome.';
    }
    // An unrecognized explanation may contain user-authored material.
    return summary;
  }

  String date(BuildContext context, DateTime value) => isSpanish
      ? MaterialLocalizations.of(context).formatShortMonthDay(value.toLocal())
      : DateTimeFormats.localMonthDay(value);
  String time(BuildContext context, DateTime value) => isSpanish
      ? MaterialLocalizations.of(
          context,
        ).formatTimeOfDay(TimeOfDay.fromDateTime(value.toLocal()))
      : DateTimeFormats.timelineTime(value);
  String upcomingOccurrence(
    BuildContext context,
    DateTime value, {
    DateTime? now,
  }) =>
      '${isSpanish ? 'Próxima ocurrencia' : 'Upcoming occurrence'} · ${dateTime(context, value, now: now)}';
  String dateTime(BuildContext context, DateTime value, {DateTime? now}) {
    if (!isSpanish) {
      return DateTimeFormats.relativeLocalDateTime(value, now: now);
    }
    final local = value.toLocal();
    final reference = (now ?? DateTime.now()).toLocal();
    final difference = DateTime.utc(local.year, local.month, local.day)
        .difference(
          DateTime.utc(reference.year, reference.month, reference.day),
        )
        .inDays;
    final day = switch (difference) {
      0 => 'Hoy',
      1 => 'Mañana',
      -1 => 'Ayer',
      _ => date(context, local),
    };
    return '$day · ${time(context, local)}';
  }
}
