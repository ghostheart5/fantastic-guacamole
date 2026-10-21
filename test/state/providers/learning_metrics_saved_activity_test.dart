import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/learning_history_provider.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/state/logs_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'saved task and goal outcomes rebuild momentum without session history',
    () {
      final now = DateTime(2026, 10, 21, 12);
      final saved = [
        _entry('task', 'task_completed', now),
        _entry('goal', 'goal_completed', now),
        _entry('skip', 'task_skipped', now),
        _entry('old', 'task_completed', now.subtract(const Duration(days: 8))),
        _entry('future', 'task_completed', now.add(const Duration(days: 1))),
        _entry('created', 'task_created', now),
      ];
      // Fresh containers model re-entry: no transient record() calls are needed.
      for (var session = 0; session < 2; session++) {
        final container = ProviderContainer(
          overrides: [
            logsProvider.overrideWith(() => _SavedLogs(saved)),
            learningProvider.overrideWith(_Learning.new),
            executionSignalsClockProvider.overrideWithValue(() => now),
          ],
        );
        expect(container.read(learningHistoryProvider), isEmpty);
        expect(
          container.read(learningMetricsProvider).momentum,
          closeTo(2 / 3, .001),
        );
        container.dispose();
      }
      final empty = ProviderContainer(
        overrides: [
          logsProvider.overrideWith(() => _SavedLogs(const [])),
          learningProvider.overrideWith(_Learning.new),
        ],
      );
      expect(empty.read(learningMetricsProvider).momentum, 0);
      empty.dispose();
    },
  );
}

LogEntryEntity _entry(String id, String source, DateTime at) => LogEntryEntity(
  id: id,
  source: source,
  message: 'Synthetic saved outcome',
  timestamp: at,
);

class _SavedLogs extends LogsController {
  _SavedLogs(this.saved);
  final List<LogEntryEntity> saved;
  @override
  LogsState build() => LogsState(entries: saved, isLoading: false);
}

class _Learning extends LearningController {
  @override
  LearningState build() => const LearningState();
}
