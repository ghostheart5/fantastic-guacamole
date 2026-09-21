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
  String get nexusTitle =>
      isSpanish ? 'NEXUS // NÚCLEO VIVO' : 'NEXUS // LIVE CORE';
  String get tagline => isSpanish
      ? 'Tu criterio amplificado: una decisión clara y futuros que puedes comparar.'
      : 'Your judgment amplified: one clear decision and futures you can compare.';
  String get logicCore => isSpanish
      ? 'AXIOMARA // SISTEMA OPERATIVO DE DECISIONES HUMANAS'
      : 'AXIOMARA // HUMAN DECISION OS';
  String get openNotifications =>
      isSpanish ? 'Abrir notificaciones' : 'Open notifications';
  String get logOut => isSpanish ? 'Cerrar sesión' : 'Log out';
  String get logOutFailed => isSpanish
      ? 'No se pudo cerrar la sesión. Inténtalo de nuevo.'
      : 'Could not log out. Please try again.';
  String get context => isSpanish ? 'CONTEXTO' : 'CONTEXT';
  String profileStatus(String name, int level, int streak) => isSpanish
      ? '${name.isEmpty ? 'SISTEMA HUMANO LISTO' : name.toUpperCase()}  ·  CAPACIDAD $level  ·  CONTINUIDAD $streak D'
      : '${name.isEmpty ? 'HUMAN SYSTEM READY' : name.toUpperCase()}  ·  CAPABILITY $level  ·  ${streak}D CONTINUITY';

  String get decisionLoop => isSpanish ? 'BUCLE DE VERDAD' : 'TRUTH LOOP';
  String get decisionLoopSubtitle => isSpanish
      ? 'Intención → decisión → acción → resultado → aprendizaje corregible'
      : 'Intent → decision → action → outcome → correctable learning';
  String get buildReality => isSpanish ? 'Construir realidad' : 'Build reality';
  String get resolveNow => isSpanish ? 'Resolver ahora' : 'Resolve now';
  String get interrogate => isSpanish ? 'Interrogar' : 'Interrogate';
  String get compareFutures =>
      isSpanish ? 'Comparar futuros' : 'Compare futures';
  String get reviewTruth => isSpanish ? 'Revisar verdad' : 'Review truth';
  String get loopControlNote => isSpanish
      ? 'Nada cambia sin tu acción. Cada resultado puede revisarse y corregirse.'
      : 'Nothing changes without your action. Every outcome can be reviewed and corrected.';
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
      ? 'Abre Trayectoria para revisar la referencia actual'
      : 'Open Trajectory to review the current baseline';
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
      isSpanish ? 'PAQUETE DE DECISIÓN EN VIVO' : 'LIVE DECISION PACKET';
  String get nextMove => isSpanish
      ? 'Ahora · Por qué · Señal · Incertidumbre · Control'
      : 'Now · Why · Signal · Uncertainty · Control';
  String get buildNextStep =>
      isSpanish ? 'Define un próximo paso claro' : 'Build one clear next step';
  String get addTaskReason => isSpanish
      ? 'Añade una tarea en Constructor de Realidad para que el Motor del Ahora ordene trabajo real.'
      : 'Add a task in Reality Builder so the Now Engine can rank real work.';
  String get scheduledReason => isSpanish
      ? 'Esta tarea programada es el compromiso concreto más próximo.'
      : 'This scheduled task is the nearest concrete commitment.';
  String workOn(String taskTitle) =>
      isSpanish ? 'Trabaja en: $taskTitle' : 'Work on: $taskTitle';
  String systemAction(String value) {
    if (!isSpanish) return value;
    const String workPrefix = 'Work on: ';
    if (value.startsWith(workPrefix)) {
      return 'Trabaja en: ${value.substring(workPrefix.length)}';
    }
    return switch (value) {
      'Take a short recovery break before choosing more work.' =>
        'Toma un breve descanso de recuperación antes de elegir más trabajo.',
      'Capture one actionable task in Creator.' =>
        'Registra una tarea realizable en el Constructor de Realidad.',
      'Reconcile unscheduled work in Smart Planner.' =>
        'Concilia el trabajo no programado en el Planificador Inteligente.',
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
      ? 'No se pudo cargar la sugerencia actual a partir de la evidencia local de planificación.'
      : 'The current suggestion could not load from local planning evidence.';
  String get retry => isSpanish ? 'Reintentar' : 'Retry';
  String get priorities =>
      isSpanish ? 'PRIORIDADES ACTUALES' : 'CURRENT PRIORITIES';
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

  String get learningChanged =>
      isSpanish ? 'QUÉ CAMBIÓ CON EL APRENDIZAJE' : 'WHAT LEARNING CHANGED';
  String get correctLearning =>
      isSpanish ? 'Corregir este aprendizaje' : 'Correct this learning';
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
  String dateTime(BuildContext context, DateTime value) {
    if (!isSpanish) return DateTimeFormats.relativeLocalDateTime(value);
    final local = value.toLocal();
    final now = DateTime.now();
    final difference = DateTime.utc(
      local.year,
      local.month,
      local.day,
    ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
    final day = switch (difference) {
      0 => 'Hoy',
      1 => 'Mañana',
      -1 => 'Ayer',
      _ => date(context, local),
    };
    return '$day · ${time(context, local)}';
  }
}
