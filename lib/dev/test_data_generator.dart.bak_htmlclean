import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dev-only test data generator. Only callable in [kDebugMode].
/// Generates a realistic dataset: 20 tasks, seeded XP, and boosted energy.
class TestDataGenerator {
  static const _taskTitles = [
    'Review quarterly goals',
    'Write morning pages',
    'Deep work: system design',
    'Read 30 minutes',
    'Weekly review session',
    'Draft project proposal',
    'Meditate for 10 minutes',
    'Plan next sprint tasks',
    'Update personal website',
    'Research new productivity tools',
    'Complete coding challenge',
    'Write retrospective notes',
    'Prepare meeting agenda',
    'Organize project files',
    'Send follow-up emails',
    'Exercise: 30 min run',
    'Learn new framework feature',
    'Create mind map for goals',
    'Refactor legacy module',
    'Capture ideas in journal',
  ];

  static Future<void> generate(WidgetRef ref, BuildContext context) async {
    if (!kDebugMode) return;

    try {
      // Seed profile XP (addXP also triggers streak logic for today)
      ref.read(profileProvider.notifier).addXP(2400);

      // Boost energy to 75% via SI state
      final si = ref.read(siStateProvider);
      ref
          .read(siStateProvider.notifier)
          .replaceState(
            energy: 0.75,
            fatigue: si.fatigue,
            completedToday: si.completedToday,
          );

      final int seed = DateTime.now().microsecondsSinceEpoch;
      for (final MapEntry<int, String> entry in _taskTitles.asMap().entries) {
        await ref
            .read(taskActionsProvider)
            .createTask(
              TaskEntity(
                id: 'dev_${seed}_${entry.key}',
                title: entry.value,
                createdAt: DateTime.now(),
                priority: (entry.key % 5) + 1,
                difficulty: (entry.key % 4) + 1,
                energyRequired: (entry.key % 3) + 1,
              ),
            );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Test data generated: 20 tasks · XP +2400 · energy 75%',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test data generation failed: $e')),
        );
      }
    }
  }
}
