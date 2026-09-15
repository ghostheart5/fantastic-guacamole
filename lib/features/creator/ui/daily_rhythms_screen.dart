import 'dart:async';

import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/services/habit_occurrence_coordinator.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
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

  Future<void> _run(
    String owner,
    HabitEntity habit,
    Future<String> Function(HabitsNotifier notifier) operation,
  ) async {
    if (!_sameAccount(owner) || _busy.contains(habit.id)) return;
    setState(() => _busy.add(habit.id));
    try {
      final String message = await operation(ref.read(habitsProvider.notifier));
      if (_sameAccount(owner)) _message(message);
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
            'Could not save that change. Your rhythm is still available; try again.',
            'No se pudo guardar el cambio. Tu ritmo sigue disponible; inténtalo de nuevo.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(habit.id));
    }
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
            'Reminders are still unavailable. Your saved rhythm has been preserved.',
            'Los recordatorios siguen sin estar disponibles. Tu ritmo guardado se conservó.',
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

  Future<void> _record(
    String owner,
    HabitEntity habit,
    bool complete,
  ) => _run(owner, habit, (notifier) async {
    final result = complete
        ? await notifier.completeHabit(habit.id)
        : await notifier.skipHabit(habit.id);
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
          title: Text(
            _t('Rename Daily Rhythm', 'Cambiar nombre del ritmo diario'),
          ),
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
      return _t('Daily Rhythm renamed.', 'Ritmo diario renombrado.');
    });
  }

  Future<void> _backfill(String owner, HabitEntity habit) async {
    final now = DateTime.now();
    final DateTime? day = await showDatePicker(
      context: context,
      initialDate: now.subtract(const Duration(days: 1)),
      firstDate: habit.createdAt.toLocal(),
      lastDate: now.subtract(const Duration(days: 1)),
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
        title: Text(_t('Remove Daily Rhythm?', '¿Eliminar el ritmo diario?')),
        content: Text(
          _t(
            'Remove "${habit.title}" from your rhythms? Previously recorded outcomes remain in your history.',
            '¿Eliminar "${habit.title}" de tus ritmos? Los resultados anteriores permanecen en tu historial.',
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
      return _t('Daily Rhythm removed.', 'Ritmo diario eliminado.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = ref.watch(accountStorageScopeProvider);
    final String? owner = scope.v2Namespace;
    final habits = ref.watch(habitsProvider);
    final occurrences = ref.watch(habitOccurrencesProvider);
    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgCreatorIntent,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TemporalScreenHeader(
                title: _t('Daily Rhythms', 'Ritmos diarios'),
                subtitle: _t(
                  'Review your rhythms and record each period’s outcome.',
                  'Revisa tus ritmos y registra el resultado de cada periodo.',
                ),
                eyebrow: _t('Consistent action', 'Acción constante'),
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 20),
              if (!scope.isWritable || owner == null)
                Text(
                  _t(
                    'Sign in to view your Daily Rhythms.',
                    'Inicia sesión para ver tus ritmos diarios.',
                  ),
                )
              else
                habits.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => _retry(
                    _t(
                      'Could not load Daily Rhythms.',
                      'No se pudieron cargar los ritmos diarios.',
                    ),
                    () => ref.invalidate(habitsProvider),
                  ),
                  data: (items) => items.isEmpty
                      ? Text(
                          _t(
                            'No Daily Rhythms yet. Return to Creator and choose Daily Rhythm to add one.',
                            'Aún no hay ritmos diarios. Vuelve a Creator y elige Ritmo diario para añadir uno.',
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (occurrences.hasError)
                              _retry(
                                _t(
                                  'Could not load period outcomes.',
                                  'No se pudieron cargar los resultados del periodo.',
                                ),
                                () => ref.invalidate(habitOccurrencesProvider),
                              ),
                            for (final habit in items)
                              _card(owner, habit, occurrences.asData?.value),
                          ],
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _retry(String text, VoidCallback retry) => Column(
    children: [
      Text(text),
      TextButton(onPressed: retry, child: Text(_t('Retry', 'Reintentar'))),
    ],
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
    final String key = HabitOccurrenceCoordinator.occurrenceKeyFor(
      habit.cadence,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TemporalGlassSurface(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(habit.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              es
                  ? '${habit.targetCount} ${habit.targetCount == 1 ? 'vez' : 'veces'} por $period · ${habit.active ? 'Activo' : 'En pausa'}'
                  : '${habit.targetCount} ${habit.targetCount == 1 ? 'time' : 'times'} per $period · ${habit.active ? 'Active' : 'Paused'}',
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
                  onPressed: canRecord
                      ? () => _record(owner, habit, true)
                      : null,
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
                    label: Text(_t('Correct outcome', 'Corregir resultado')),
                  ),
                if (habit.active)
                  TextButton.icon(
                    onPressed: busy ? null : () => _backfill(owner, habit),
                    icon: const Icon(Icons.history_rounded),
                    label: Text(_t('Record earlier', 'Registrar anterior')),
                  ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => _run(owner, habit, (notifier) async {
                          await notifier.toggleHabit(habit.id);
                          return habit.active
                              ? _t(
                                  'Daily Rhythm paused.',
                                  'Ritmo diario en pausa.',
                                )
                              : _t(
                                  'Daily Rhythm resumed.',
                                  'Ritmo diario reanudado.',
                                );
                        }),
                  child: Text(
                    habit.active
                        ? _t('Pause', 'Pausar')
                        : _t('Resume', 'Reanudar'),
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
    );
  }
}
