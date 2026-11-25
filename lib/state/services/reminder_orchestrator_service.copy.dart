part of 'reminder_orchestrator_service.dart';

/// Goal, rhythm and daily planning reminder text in the app language. Task
/// reminder text is in [_TaskReminderCopy].
class _ReminderCopy {
  const _ReminderCopy(this.spanish);

  final bool spanish;

  String _name(String title) => spanish ? '«$title»' : '"$title"';

  String _steps(int done, int total) => total <= 0
      ? ''
      : spanish
      ? ' $done de $total pasos hechos.'
      : ' $done of $total steps done.';

  /// The deadline reminder [daysBefore] (3, 1 or 0) days before the target.
  String goalDeadlineTitle(int daysBefore) => switch (daysBefore) {
    3 => spanish ? 'Meta próxima' : 'Goal coming up',
    1 => spanish ? 'Meta para mañana' : 'Goal due tomorrow',
    _ => spanish ? 'Meta para hoy' : 'Goal due today',
  };

  String goalDeadlineBody(String title, int daysBefore, int done, int total) {
    final String when = switch (daysBefore) {
      3 => spanish ? 'vence en 3 días' : 'is due in 3 days',
      1 => spanish ? 'vence mañana' : 'is due tomorrow',
      _ => spanish ? 'vence hoy' : 'is due today',
    };
    return '${_name(title)} $when.${_steps(done, total)}';
  }

  String get goalOverdueTitle => spanish ? 'Meta vencida' : 'Goal overdue';

  String goalOverdueBody(String title, int done, int total) => spanish
      ? '${_name(title)} venció ayer y sigue pendiente.${_steps(done, total)}'
      : '${_name(title)} was due yesterday and is still open.'
            '${_steps(done, total)}';

  String get goalCloseTitle => spanish ? 'Ya casi' : 'Almost there';

  String goalCloseBody(String title, int remaining) => remaining <= 0
      ? (spanish
            ? 'Todos los pasos de ${_name(title)} están hechos. Marca la meta '
                  'como completada cuando quieras.'
            : 'Every step for ${_name(title)} is done. Mark the goal complete '
                  'when you are ready.')
      : remaining == 1
      ? (spanish
            ? 'Queda un paso en ${_name(title)}.'
            : 'One step left on ${_name(title)}.')
      : (spanish
            ? 'Quedan $remaining pasos en ${_name(title)}. Ya casi lo logras.'
            : '$remaining steps left on ${_name(title)}. You are close.');

  /// The rhythm's own title is the reminder title.
  String habitBody(String title) => spanish
      ? 'Es hora de ${_name(title)}. Toca para registrarlo.'
      : 'Time for ${_name(title)}. Tap to check in.';

  String get dailyPlanningTitle => spanish
      ? 'Recordatorio de planificación diaria'
      : 'Daily Planning Reminder';

  String get dailyPlanningBody => spanish
      ? 'Abre Axiomara y elige un próximo paso manejable.'
      : 'Open Axiomara and choose one manageable next step.';
}
