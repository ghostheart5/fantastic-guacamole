import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/state/logs_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('replaced calculation cannot start a deferred timer', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [logsProvider.overrideWith(() => _Logs(const []))],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(executionSignalsProvider, (_, _) {});
    container.invalidate(executionSignalsProvider);
    container.read(executionSignalsProvider);
    // Advance the container's zero-delay refresh scheduler as well as microtasks.
    await tester.pump(const Duration(milliseconds: 1));
    subscription.close();
    await tester.pump();
    // Flutter checks for leaked timers before addTearDown disposes the container.
  });

  testWidgets('cached calculation stops on detach and refreshes on return', (
    tester,
  ) async {
    DateTime now = DateTime(2026, 9, 11, 23, 59, 55);
    final container = ProviderContainer(
      overrides: [
        executionSignalsClockProvider.overrideWithValue(() => now),
        logsProvider.overrideWith(
          () => _Logs([_entry('today', DateTime(2026, 9, 11, 20))]),
        ),
      ],
    );
    addTearDown(container.dispose);
    final derived = Provider((ref) => ref.watch(executionSignalsProvider));
    Widget screen() => UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, child) {
          return Text(
            '${ref.watch(derived).completedToday}',
            textDirection: TextDirection.ltr,
          );
        },
      ),
    );
    await tester.pumpWidget(screen());
    expect(find.text('1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    now = now.add(const Duration(seconds: 6));
    await tester.pumpWidget(screen());
    await tester.pump();
    expect(find.text('0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    // The retained container is deliberately disposed after Flutter checks
    // pending timers, so this also verifies that detached UI leaves none.
  });

  testWidgets('recent evidence expires without a new log or manual refresh', (
    tester,
  ) async {
    DateTime now = DateTime(2026, 9, 11, 12);
    final entryAt = now
        .subtract(const Duration(days: 7))
        .add(const Duration(seconds: 10));
    final container = ProviderContainer(
      overrides: [
        executionSignalsClockProvider.overrideWithValue(() => now),
        logsProvider.overrideWith(() => _Logs([_entry('edge', entryAt)])),
      ],
    );
    addTearDown(container.dispose);
    container.listen(executionSignalsProvider, (_, _) {});
    expect(container.read(executionSignalsProvider).completed7d, 1);
    now = now.add(const Duration(seconds: 11));
    await tester.pump(const Duration(seconds: 11));
    expect(container.read(executionSignalsProvider).completed7d, 0);
    expect(container.read(executionSignalsProvider).completedPrevious7d, 1);
    container.dispose();
  });

  testWidgets('today uses local dates and rolls over at local midnight', (
    tester,
  ) async {
    DateTime now = DateTime(2026, 9, 11, 23, 59, 55);
    final container = ProviderContainer(
      overrides: [
        executionSignalsClockProvider.overrideWithValue(() => now.toUtc()),
        logsProvider.overrideWith(
          () => _Logs([
            _entry('today', DateTime(2026, 9, 11, 20).toUtc()),
            _entry('yesterday', DateTime(2026, 9, 10, 20).toUtc()),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(executionSignalsProvider, (_, _) {});
    expect(container.read(executionSignalsProvider).completedToday, 1);
    expect(container.read(executionSignalsProvider).completed7d, 2);
    now = now.add(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 6));
    expect(container.read(executionSignalsProvider).completedToday, 0);
    expect(container.read(executionSignalsProvider).completed7d, 2);
    container.dispose();
  });
}

LogEntryEntity _entry(String id, DateTime at) => LogEntryEntity(
  id: id,
  message: 'Completed a real task',
  source: 'task_completed',
  timestamp: at,
);

class _Logs extends LogsController {
  _Logs(this.entries);
  final List<LogEntryEntity> entries;
  @override
  LogsState build() => LogsState(entries: entries, isLoading: false);
}
