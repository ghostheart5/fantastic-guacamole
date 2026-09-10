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
          'Your change was saved, but reminders could not update.',
          onRetry: () {
            unawaited(_retryReminders(owner));
          },
        );
      }
    } catch (_) {
      if (_sameAccount(owner)) {
        _message(
          'Could not save that change. Your rhythm is still available; try again.',
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
      if (_sameAccount(owner)) _message('Reminders updated.');
    } catch (_) {
      if (_sameAccount(owner)) {
        _message(
          'Reminders are still unavailable. Your saved rhythm has been preserved.',
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
              : SnackBarAction(label: 'Retry reminders', onPressed: onRetry),
        ),
      );
  }

  Future<void> _record(String owner, HabitEntity habit, bool complete) =>
      _run(owner, habit, (notifier) async {
        final result = complete
            ? await notifier.completeHabit(habit.id)
            : await notifier.skipHabit(habit.id);
        if (result.mutation == HabitOccurrenceMutation.conflict) {
          return 'This period already has a different recorded outcome.';
        }
        if (result.mutation == HabitOccurrenceMutation.idempotent) {
          return 'This period was already recorded. No duplicate was added.';
        }
        return complete
            ? 'Target completed for this period.'
            : 'This period was skipped.';
      });

  Future<void> _rename(String owner, HabitEntity habit) async {
    String draftTitle = habit.title;
    final String? title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Rename Daily Rhythm'),
          content: TextFormField(
            initialValue: habit.title,
            maxLength: 160,
            decoration: const InputDecoration(labelText: 'Title'),
            onChanged: (value) => update(() => draftTitle = value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: draftTitle.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, draftTitle.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (title == null || !_sameAccount(owner)) return;
    await _run(owner, habit, (notifier) async {
      await notifier.renameHabit(habit.id, title);
      return 'Daily Rhythm renamed.';
    });
  }

  Future<void> _remove(String owner, HabitEntity habit) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Daily Rhythm?'),
        content: Text(
          'Remove "${habit.title}" from your rhythms? Previously recorded outcomes remain in your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !_sameAccount(owner)) return;
    await _run(owner, habit, (notifier) async {
      await notifier.removeHabit(habit.id);
      return 'Daily Rhythm removed.';
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
                title: 'Daily Rhythms',
                subtitle:
                    'Review your rhythms and record each period’s outcome.',
                eyebrow: 'Consistent action',
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 20),
              if (!scope.isWritable || owner == null)
                const Text('Sign in to view your Daily Rhythms.')
              else
                habits.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => _retry(
                    'Could not load Daily Rhythms.',
                    () => ref.invalidate(habitsProvider),
                  ),
                  data: (items) => items.isEmpty
                      ? const Text(
                          'No Daily Rhythms yet. Return to Creator and choose Daily Rhythm to add one.',
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (occurrences.hasError)
                              _retry(
                                'Could not load period outcomes.',
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
      TextButton(onPressed: retry, child: const Text('Retry')),
    ],
  );

  Widget _card(
    String owner,
    HabitEntity habit,
    List<HabitOccurrenceEntity>? outcomes,
  ) {
    final String period = switch (habit.cadence) {
      HabitCadence.daily => 'day',
      HabitCadence.weekly => 'week',
      HabitCadence.monthly => 'month',
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
        ? '${current.outcome == HabitOccurrenceOutcome.completed ? 'Completed' : 'Skipped'} this $period'
        : habit.active
        ? 'Not recorded this $period'
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
              '${habit.targetCount} ${habit.targetCount == 1 ? 'time' : 'times'} per $period · ${habit.active ? 'Active' : 'Paused'}',
            ),
            if (habit.description?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Text(habit.description!),
            ],
            const SizedBox(height: 8),
            Text(outcomes == null ? 'Loading this period’s outcome…' : status),
            const SizedBox(height: 8),
            Text('Mark complete when the full target for this $period is met.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: canRecord
                      ? () => _record(owner, habit, true)
                      : null,
                  child: const Text('Mark target completed'),
                ),
                OutlinedButton(
                  onPressed: canRecord
                      ? () => _record(owner, habit, false)
                      : null,
                  child: Text('Skip this $period'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => _run(owner, habit, (notifier) async {
                          await notifier.toggleHabit(habit.id);
                          return habit.active
                              ? 'Daily Rhythm paused.'
                              : 'Daily Rhythm resumed.';
                        }),
                  child: Text(habit.active ? 'Pause' : 'Resume'),
                ),
                TextButton(
                  onPressed: busy ? null : () => _rename(owner, habit),
                  child: const Text('Rename'),
                ),
                TextButton(
                  onPressed: busy ? null : () => _remove(owner, habit),
                  child: const Text('Remove'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
