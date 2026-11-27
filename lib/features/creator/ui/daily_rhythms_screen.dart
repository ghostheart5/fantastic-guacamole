import 'dart:async';

import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/planning/habit_reminder_days.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/features/creator/widgets/habit_reminder_day_pickers.dart';
import 'package:fantastic_guacamole/features/creator/widgets/habit_reminder_line.dart';
import 'package:fantastic_guacamole/features/permissions/notification_permission_flow.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/services/habit_occurrence_coordinator.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/tutorial/guidance_catalogue.dart';
import 'package:fantastic_guacamole/tutorial/guide_hint_place.dart';
import 'package:fantastic_guacamole/ui/widgets/plain/plain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Readback and outcome controls for the rhythms saved through Creator.
class DailyRhythmsScreen extends ConsumerStatefulWidget {
  const DailyRhythmsScreen({super.key});

  @override
  ConsumerState<DailyRhythmsScreen> createState() => _DailyRhythmsScreenState();
}

class _DailyRhythmsScreenState extends ConsumerState<DailyRhythmsScreen> {
  final Set<String> _busy = <String>{};
  Timer? _periodTimer;

  String _t(String english, String spanish) =>
      Localizations.localeOf(context).languageCode == 'es' ? spanish : english;

  @override
  void initState() {
    super.initState();
    // Refresh period labels when the screen stays open across midnight.
    _periodTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _periodTimer?.cancel();
    super.dispose();
  }

  bool _sameAccount(String owner) {
    if (!mounted) return false;
    final scope = ref.read(accountStorageScopeProvider);
    return scope.isWritable && scope.v2Namespace == owner;
  }

  /// True only when the change and its reminder update both finished.
  Future<bool> _run(
    String owner,
    HabitEntity habit,
    Future<String> Function(HabitsNotifier notifier) operation,
  ) async {
    if (!_sameAccount(owner) || _busy.contains(habit.id)) return false;
    setState(() => _busy.add(habit.id));
    try {
      final String message = await operation(ref.read(habitsProvider.notifier));
      if (_sameAccount(owner)) _message(message);
      return true;
    } on RhythmReminderSyncException {
      if (_sameAccount(owner)) {
        _message(
          _t(
            'Your change was saved, but reminders could not update.',
            'El cambio se guardó, pero los recordatorios no se actualizaron.',
          ),
          onRetry: () {
            unawaited(_retryReminders(owner));
          },
        );
      }
    } catch (_) {
      if (_sameAccount(owner)) {
        _message(
          _t(
            'Could not save that change. Your habit is still available; try again.',
            'No se pudo guardar el cambio. Tu hábito sigue disponible; inténtalo de nuevo.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(habit.id));
    }
    return false;
  }

  Future<void> _retryReminders(String owner) async {
    if (!_sameAccount(owner)) return;
    try {
      await ref.read(habitsProvider.notifier).retryReminders();
      if (_sameAccount(owner)) {
        _message(_t('Reminders updated.', 'Recordatorios actualizados.'));
      }
    } catch (_) {
      if (_sameAccount(owner)) {
        _message(
          _t(
            'Reminders are still unavailable. Your saved habit has been preserved.',
            'Los recordatorios siguen sin estar disponibles. Tu hábito guardado se conservó.',
          ),
        );
      }
    }
  }

  void _message(String text, {VoidCallback? onRetry}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          action: onRetry == null
              ? null
              : SnackBarAction(
                  label: _t('Retry reminders', 'Reintentar recordatorios'),
                  onPressed: onRetry,
                ),
        ),
      );
  }

  /// A check-in that was really saved is what the Habits hint is about; it
  /// then stays away.
  void _checkedIn(String owner) {
    if (!_sameAccount(owner)) return;
    ref
        .read(adaptiveGuidanceProvider.notifier)
        .recordIfMissing(GuidanceMilestone.firstHabitCheckIn)
        .ignore();
  }

  Future<void> _record(
    String owner,
    HabitEntity habit,
    bool complete,
  ) => _run(owner, habit, (notifier) async {
    final HabitOccurrenceResult result;
    try {
      result = complete
          ? await notifier.completeHabit(habit.id)
          : await notifier.skipHabit(habit.id);
    } on RhythmReminderSyncException {
      // The outcome was saved; only the reminder update failed.
      _checkedIn(owner);
      rethrow;
    }
    if (result.mutation == HabitOccurrenceMutation.applied) _checkedIn(owner);
    if (result.mutation == HabitOccurrenceMutation.conflict) {
      return _t(
        'This period already has a different recorded outcome.',
        'Este periodo ya tiene un resultado diferente registrado.',
      );
    }
    if (result.mutation == HabitOccurrenceMutation.idempotent) {
      return result.learningPending
          ? _t(
              'This period was already recorded. Learning history will retry later.',
              'Este periodo ya estaba registrado. El historial de aprendizaje se reintentará después.',
            )
          : _t(
              'This period was already recorded. No duplicate was added.',
              'Este periodo ya estaba registrado. No se añadió un duplicado.',
            );
    }
    if (result.learningPending) {
      return _t(
        'Outcome recorded. Learning history will retry later.',
        'Resultado registrado. El historial de aprendizaje se reintentará después.',
      );
    }
    return complete
        ? _t(
            'Target completed for this period.',
            'Objetivo completado en este periodo.',
          )
        : _t('This period was skipped.', 'Este periodo se omitió.');
  });

  Future<void> _rename(String owner, HabitEntity habit) async {
    String draftTitle = habit.title;
    final String? title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(_t('Rename habit', 'Cambiar nombre del hábito')),
          content: TextFormField(
            initialValue: habit.title,
            maxLength: 160,
            decoration: InputDecoration(labelText: _t('Title', 'Título')),
            onChanged: (value) => update(() => draftTitle = value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_t('Cancel', 'Cancelar')),
            ),
            FilledButton(
              onPressed: draftTitle.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, draftTitle.trim()),
              child: Text(_t('Save', 'Guardar')),
            ),
          ],
        ),
      ),
    );
    if (title == null || !_sameAccount(owner)) return;
    await _run(owner, habit, (notifier) async {
      await notifier.renameHabit(habit.id, title);
      return _t('Habit renamed.', 'Hábito renombrado.');
    });
  }

  Future<void> _editFrequency(String owner, HabitEntity habit) async {
    var cadence = habit.cadence;
    var target = habit.targetCount;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(_t('Edit frequency', 'Editar frecuencia')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _t(
                  'Earlier outcomes stay in history. The new frequency controls current and future periods.',
                  'Los resultados anteriores se conservan. La nueva frecuencia controla los periodos actuales y futuros.',
                ),
              ),
              DropdownButton<HabitCadence>(
                value: cadence,
                isExpanded: true,
                items: [
                  for (final value in HabitCadence.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(switch (value) {
                        HabitCadence.daily => _t('Daily', 'Diario'),
                        HabitCadence.weekly => _t('Weekly', 'Semanal'),
                        HabitCadence.monthly => _t('Monthly', 'Mensual'),
                      }),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) update(() => cadence = value);
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: _t('Decrease target', 'Reducir objetivo'),
                    onPressed: target > 1 ? () => update(() => target--) : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Text('$target'),
                  IconButton(
                    tooltip: _t('Increase target', 'Aumentar objetivo'),
                    onPressed: target < 365
                        ? () => update(() => target++)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_t('Cancel', 'Cancelar')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_t('Save', 'Guardar')),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !_sameAccount(owner)) return;
    await _run(owner, habit, (notifier) async {
      await notifier.updateFrequency(habit.id, cadence, target);
      return _t('Frequency saved.', 'Frecuencia guardada.');
    });
  }

  String _reminderLabel(HabitEntity habit) {
    final int? minutes = habit.reminderMinutes;
    if (minutes == null) {
      return _t('No reminder set', 'Sin recordatorio');
    }
    final String time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));
    final String when = HabitReminderDays.describe(
      cadence: habit.cadence,
      weekdays: habit.reminderWeekdays,
      dayOfMonth: habit.reminderDayOfMonth,
      spanish: _spanish,
    );
    return _t('Reminder: $time $when', 'Recordatorio: $time $when');
  }

  bool get _spanish => Localizations.localeOf(context).languageCode == 'es';

  /// Asks which weekdays (weekly) or which day of the month (monthly) the
  /// reminder arrives on. Null when cancelled.
  Future<({List<int>? weekdays, int? dayOfMonth})?> _pickReminderDays(
    HabitEntity habit,
  ) async {
    List<int>? weekdays = habit.reminderWeekdays;
    int? day = habit.reminderDayOfMonth;
    final bool weekly = habit.cadence == HabitCadence.weekly;
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          scrollable: true,
          title: Text(
            weekly
                ? _t('Remind me on', 'Recordarme los')
                : _t('Remind me on the', 'Recordarme el'),
          ),
          content: weekly
              ? HabitWeekdayChooser(
                  selected: weekdays,
                  spanish: _spanish,
                  onChanged: (value) => update(() => weekdays = value),
                )
              : HabitMonthDayChooser(
                  selected: day,
                  spanish: _spanish,
                  onChanged: (value) => update(() => day = value),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_t('Cancel', 'Cancelar')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_t('Save', 'Guardar')),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return null;
    return weekly
        ? (weekdays: weekdays ?? const <int>[DateTime.monday], dayOfMonth: null)
        : (weekdays: null, dayOfMonth: day ?? 1);
  }

  Future<void> _editReminder(String owner, HabitEntity habit) async {
    final int? current = habit.reminderMinutes;
    // Weekly and monthly reminders also say which days they arrive on.
    final bool hasDays = habit.cadence != HabitCadence.daily;
    if (current != null) {
      final String? choice = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: Text(_t('Reminder', 'Recordatorio')),
          content: Text(_reminderLabel(habit)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'remove'),
              child: Text(_t('Turn off', 'Desactivar')),
            ),
            if (hasDays)
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, 'days'),
                child: Text(
                  habit.cadence == HabitCadence.weekly
                      ? _t('Change days', 'Cambiar días')
                      : _t('Change day', 'Cambiar día'),
                ),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'change'),
              child: Text(_t('Change time', 'Cambiar hora')),
            ),
          ],
        ),
      );
      if (choice == null || !_sameAccount(owner)) return;
      if (choice == 'remove') {
        await _run(owner, habit, (notifier) async {
          await notifier.setReminderTime(habit.id, null);
          return _t('Reminder turned off.', 'Recordatorio desactivado.');
        });
        return;
      }
      if (choice == 'days') {
        final days = await _pickReminderDays(habit);
        if (days == null || !_sameAccount(owner)) return;
        await _run(owner, habit, (notifier) async {
          await notifier.setReminderTime(
            habit.id,
            current,
            weekdays: days.weekdays,
            dayOfMonth: days.dayOfMonth,
          );
          return _reminderLabel(
            habit.copyWith(
              reminderWeekdays: days.weekdays,
              reminderDayOfMonth: days.dayOfMonth,
            ),
          );
        });
        return;
      }
    }
    if (!mounted) return;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      helpText: _t('Remind me at', 'Recordarme a las'),
      initialTime: current == null
          ? const TimeOfDay(hour: 17, minute: 0)
          : TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null || !_sameAccount(owner)) return;
    // A new weekly or monthly reminder asks for its days right away.
    final days = current == null && hasDays
        ? await _pickReminderDays(habit)
        : null;
    if ((current == null && hasDays && days == null) || !_sameAccount(owner)) {
      return;
    }
    final bool saved = await _run(owner, habit, (notifier) async {
      await notifier.setReminderTime(
        habit.id,
        picked.hour * 60 + picked.minute,
        weekdays: days?.weekdays,
        dayOfMonth: days?.dayOfMonth,
      );
      return _reminderLabel(
        habit.copyWith(
          reminderMinutes: picked.hour * 60 + picked.minute,
          reminderWeekdays: days?.weekdays,
          reminderDayOfMonth: days?.dayOfMonth,
        ),
      );
    });
    // The person just asked for a reminder and it is saved: the moment to
    // ask for notification permission, once.
    if (!saved || !mounted || !_sameAccount(owner)) return;
    await ensureNotificationPermission(context, ref, afterSave: true);
  }

  Future<void> _backfill(String owner, HabitEntity habit) async {
    final now = DateTime.now();
    final created = (habit.frequencyStartedAt ?? habit.createdAt).toLocal();
    final first = DateTime(created.year, created.month, created.day);
    final last = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));
    if (first.isAfter(last)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'No earlier day is available. This habit was created today.',
              'No hay un día anterior disponible. Este hábito se creó hoy.',
            ),
          ),
        ),
      );
      return;
    }
    final DateTime? day = await showDatePicker(
      context: context,
      initialDate: last,
      firstDate: first,
      lastDate: last,
    );
    if (day == null || !mounted) return;
    final bool? completed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          _t('Record earlier outcome', 'Registrar resultado anterior'),
        ),
        content: Text(
          _t(
            'Was the target completed for the selected period?',
            '¿Se completó el objetivo en el periodo seleccionado?',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_t('Cancel', 'Cancelar')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_t('Skipped', 'Omitido')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_t('Completed', 'Completado')),
          ),
        ],
      ),
    );
    if (completed == null || !mounted) return;
    await _run(owner, habit, (notifier) async {
      final result = await notifier.recordHabitAt(
        habit.id,
        DateTime(day.year, day.month, day.day, 12),
        completed: completed,
      );
      if (result.mutation == HabitOccurrenceMutation.conflict) {
        return _t(
          'That period already has a different outcome. Use its correction control.',
          'Ese periodo ya tiene otro resultado. Usa su control de corrección.',
        );
      }
      return _t('Earlier outcome recorded.', 'Resultado anterior registrado.');
    });
  }

  Future<void> _remove(String owner, HabitEntity habit) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('Remove habit?', '¿Eliminar el hábito?')),
        content: Text(
          _t(
            'Remove "${habit.title}" from your habits? Previously recorded outcomes remain in your history.',
            '¿Eliminar "${habit.title}" de tus hábitos? Los resultados anteriores permanecen en tu historial.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('Cancel', 'Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('Remove', 'Eliminar')),
          ),
        ],
      ),
    );
    if (confirmed != true || !_sameAccount(owner)) return;
    await _run(owner, habit, (notifier) async {
      await notifier.removeHabit(habit.id);
      return _t('Habit removed.', 'Hábito eliminado.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = ref.watch(accountStorageScopeProvider);
    final String? owner = scope.v2Namespace;
    final habits = ref.watch(habitsProvider);
    final occurrences = ref.watch(habitOccurrencesProvider);
    // Opened on top of other screens, so it says itself where the person is.
    return GuideHintPlace(
      place: GuidancePlaces.habits,
      child: _page(scope.isWritable, owner, habits, occurrences),
    );
  }

  Widget _page(
    bool writable,
    String? owner,
    AsyncValue<List<HabitEntity>> habits,
    AsyncValue<List<HabitOccurrenceEntity>> occurrences,
  ) {
    final ThemeData theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        visualDensity: VisualDensity.standard,
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
      child: PlainScreen(
        children: <Widget>[
          PlainHeader(
            title: _t('Habits', 'Hábitos'),
            actions: <PlainHeaderAction>[
              PlainHeaderAction(
                icon: Icons.arrow_back_rounded,
                label: _t('Back', 'Atrás'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Text(
            _t(
              'Choose a habit to mark what happened or change how often it repeats.',
              'Elige un hábito para registrar lo que pasó o cambiar su frecuencia.',
            ),
          ),
          const SizedBox(height: 16),
          if (!writable || owner == null)
            PlainEmptyState(
              message: _t(
                'Sign in to view your habits.',
                'Inicia sesión para ver tus hábitos.',
              ),
            )
          else
            habits.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _retry(
                _t(
                  'Could not load habits.',
                  'No se pudieron cargar los hábitos.',
                ),
                () => ref.invalidate(habitsProvider),
              ),
              data: (items) => items.isEmpty
                  ? PlainEmptyState(
                      message: _t(
                        'No habits yet. Go to Add something and choose Habit to save one.',
                        'Aún no hay hábitos. Ve a Añadir algo y elige Hábito para guardar uno.',
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (occurrences.hasError)
                          _retry(
                            _t(
                              'Could not load period outcomes.',
                              'No se pudieron cargar los resultados del periodo.',
                            ),
                            () => ref.invalidate(habitOccurrencesProvider),
                          ),
                        for (final HabitEntity habit in items)
                          _card(owner, habit, occurrences.asData?.value),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  Widget _retry(String text, VoidCallback retry) => PlainEmptyState(
    message: text,
    actionLabel: _t('Retry', 'Reintentar'),
    onAction: retry,
  );

  Widget _card(
    String owner,
    HabitEntity habit,
    List<HabitOccurrenceEntity>? outcomes,
  ) {
    final bool es = Localizations.localeOf(context).languageCode == 'es';
    final String period = switch (habit.cadence) {
      HabitCadence.daily => es ? 'día' : 'day',
      HabitCadence.weekly => es ? 'semana' : 'week',
      HabitCadence.monthly => es ? 'mes' : 'month',
    };
    final String key = RhythmPlanningContext.occurrenceKey(
      habit,
      DateTime.now(),
    );
    HabitOccurrenceEntity? current;
    for (final outcome in outcomes ?? const <HabitOccurrenceEntity>[]) {
      if (outcome.habitId == habit.id && outcome.occurrenceKey == key) {
        current = outcome;
      }
    }
    final bool busy = _busy.contains(habit.id);
    final bool canRecord =
        habit.active && current == null && outcomes != null && !busy;
    final String status = current != null
        ? '${current.outcome == HabitOccurrenceOutcome.completed ? (es ? 'Completado' : 'Completed') : (es ? 'Omitido' : 'Skipped')} ${es ? 'en este' : 'this'} $period'
        : habit.active
        ? '${es ? 'Sin registrar en este' : 'Not recorded this'} $period'
        : es
        ? 'En pausa'
        : 'Paused';
    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            habit.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: PlainPalette.card(Theme.of(context)).primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            es
                ? '${habit.targetCount} ${habit.targetCount == 1 ? 'vez' : 'veces'} por $period · ${habit.active ? 'Activo' : 'En pausa'}'
                : '${habit.targetCount} ${habit.targetCount == 1 ? 'time' : 'times'} per $period · ${habit.active ? 'Active' : 'Paused'}',
          ),
          const SizedBox(height: 4),
          habit.reminderMinutes == null
              ? Text(
                  _reminderLabel(habit),
                  key: ValueKey<String>('rhythm-reminder-label-${habit.id}'),
                )
              : HabitReminderLine(
                  habitId: habit.id,
                  label: _reminderLabel(habit),
                ),
          if (habit.description?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(habit.description!),
          ],
          const SizedBox(height: 8),
          Text(
            outcomes == null
                ? _t(
                    'Loading this period’s outcome…',
                    'Cargando el resultado de este periodo…',
                  )
                : status,
          ),
          const SizedBox(height: 8),
          Text(
            _t(
              'Mark complete when the full target for this $period is met.',
              'Marca como completado cuando alcances el objetivo completo de este $period.',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: canRecord ? () => _record(owner, habit, true) : null,
                child: Text(
                  _t('Mark target completed', 'Marcar objetivo completado'),
                ),
              ),
              OutlinedButton(
                onPressed: canRecord
                    ? () => _record(owner, habit, false)
                    : null,
                child: Text(_t('Skip this $period', 'Omitir este $period')),
              ),
              if (current != null && habit.active)
                TextButton.icon(
                  key: ValueKey<String>('correct-rhythm-${habit.id}'),
                  onPressed: busy
                      ? null
                      : () => _run(owner, habit, (notifier) async {
                          final next =
                              current!.outcome ==
                                  HabitOccurrenceOutcome.completed
                              ? HabitOccurrenceOutcome.skipped
                              : HabitOccurrenceOutcome.completed;
                          final result = await notifier.correctHabit(
                            habit.id,
                            next,
                          );
                          return result.learningPending
                              ? _t(
                                  'Outcome corrected. Learning history will retry later.',
                                  'Resultado corregido. El historial de aprendizaje se reintentará después.',
                                )
                              : _t(
                                  'Outcome corrected. The earlier result remains in correction history.',
                                  'Resultado corregido. El resultado anterior permanece en el historial de correcciones.',
                                );
                        }),
                  icon: const Icon(Icons.undo_rounded),
                  label: Text(
                    current.outcome == HabitOccurrenceOutcome.completed
                        ? _t('Change to skipped', 'Cambiar a omitido')
                        : _t('Change to completed', 'Cambiar a completado'),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ExpansionTile(
                  key: ValueKey('habit-options-${habit.id}'),
                  tilePadding: EdgeInsets.zero,
                  title: Text(_t('Habit options', 'Opciones del h\u00e1bito')),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (habit.active)
                          TextButton.icon(
                            onPressed: busy
                                ? null
                                : () => _backfill(owner, habit),
                            icon: const Icon(Icons.history_rounded),
                            label: Text(
                              _t('Record earlier', 'Registrar anterior'),
                            ),
                          ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => _run(owner, habit, (notifier) async {
                                  await notifier.toggleHabit(habit.id);
                                  return habit.active
                                      ? _t('Habit paused.', 'Hábito en pausa.')
                                      : _t(
                                          'Habit resumed.',
                                          'Hábito reanudado.',
                                        );
                                }),
                          child: Text(
                            habit.active
                                ? _t('Pause', 'Pausar')
                                : _t('Resume', 'Reanudar'),
                          ),
                        ),
                        TextButton(
                          key: ValueKey<String>('rhythm-reminder-${habit.id}'),
                          onPressed: busy
                              ? null
                              : () => _editReminder(owner, habit),
                          child: Text(
                            habit.reminderMinutes == null
                                ? _t('Set reminder', 'Poner recordatorio')
                                : _t('Reminder', 'Recordatorio'),
                          ),
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => _editFrequency(owner, habit),
                          child: Text(
                            _t('Edit frequency', 'Editar frecuencia'),
                          ),
                        ),
                        TextButton(
                          onPressed: busy ? null : () => _rename(owner, habit),
                          child: Text(_t('Rename', 'Renombrar')),
                        ),
                        TextButton(
                          onPressed: busy ? null : () => _remove(owner, habit),
                          child: Text(_t('Remove', 'Eliminar')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
