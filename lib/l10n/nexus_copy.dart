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

  String get tagline => isSpanish
      ? 'Tu día, organizado en un próximo paso claro.'
      : 'Your day, resolved into one clear move.';
  String get logicCore =>
      isSpanish ? 'NÚCLEO DE LÓGICA ADAPTATIVA' : 'ADAPTIVE LOGIC CORE';
  String get openNotifications =>
      isSpanish ? 'Abrir notificaciones' : 'Open notifications';
  String get logOut => isSpanish ? 'Cerrar sesión' : 'Log out';
  String get logOutFailed => isSpanish
      ? 'No se pudo cerrar la sesión. Inténtalo de nuevo.'
      : 'Could not log out. Please try again.';
  String get context => isSpanish ? 'CONTEXTO' : 'CONTEXT';
  String profileStatus(String name, int level, int streak) => isSpanish
      ? '${name.isEmpty ? 'TU DÍA ESTÁ LISTO' : name.toUpperCase()}  ·  NIVEL $level  ·  RACHA DE $streak D'
      : '${name.isEmpty ? 'TODAY IS READY' : name.toUpperCase()}  ·  LVL $level  ·  ${streak}D STREAK';

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
          'BUILDING' => 'EN DESARROLLO',
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
      isSpanish ? 'DECISIÓN ACTUAL' : 'CURRENT DECISION';
  String get nextMove =>
      isSpanish ? 'Próximo paso recomendado' : 'Recommended next move';
  String get buildNextStep =>
      isSpanish ? 'Define un próximo paso claro' : 'Build one clear next step';
  String get addTaskReason => isSpanish
      ? 'Añade una tarea en Creador para que el Planificador Inteligente ordene trabajo real.'
      : 'Add a task in Creator so Smart Planner can rank real work.';
  String get scheduledReason => isSpanish
      ? 'Esta tarea programada es el compromiso concreto más próximo.'
      : 'This scheduled task is the nearest concrete commitment.';
  String workOn(String taskTitle) =>
      isSpanish ? 'Trabaja en: $taskTitle' : 'Work on: $taskTitle';
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
      isSpanish ? 'Revisar sugerencia' : 'Review suggestion';
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
      ? 'Opcional. Se usa para planificar durante un máximo de dos horas mientras la aplicación permanece abierta. Puedes borrarlo cuando quieras.'
      : 'Optional. Used for planning for up to two hours while the app stays open. You can clear it at any time.';
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
