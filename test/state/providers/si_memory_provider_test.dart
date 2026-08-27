import 'package:fantastic_guacamole/state/models/si_memory_models.dart';
import 'package:fantastic_guacamole/state/providers/si_memory_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'capture appends snapshots and latestSiSnapshotProvider returns newest',
    () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final SISnapshot first = SISnapshot(
        timestamp: DateTime.utc(2026, 7, 5, 10),
        energy: 0.6,
        fatigue: 0.3,
        completed: 1,
        skipped: 0,
        responseSummary: 'first',
        responseHash: 'h1',
        actionKey: 'a1',
      );
      final SISnapshot second = SISnapshot(
        timestamp: DateTime.utc(2026, 7, 5, 11),
        energy: 0.7,
        fatigue: 0.2,
        completed: 2,
        skipped: 0,
        responseSummary: 'second',
        responseHash: 'h2',
        actionKey: 'a2',
      );

      container.read(siMemoryProvider.notifier).capture(first);
      container.read(siMemoryProvider.notifier).capture(second);

      final memory = container.read(siMemoryProvider);
      expect(memory.entries, hasLength(2));
      expect(
        container.read(latestSiSnapshotProvider)?.responseSummary,
        'second',
      );
    },
  );

  test('clear removes memory snapshots', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(siMemoryProvider.notifier)
        .capture(
          SISnapshot(
            timestamp: DateTime.utc(2026, 7, 5, 10),
            energy: 0.5,
            fatigue: 0.4,
            completed: 0,
            skipped: 1,
            responseSummary: 'temp',
            responseHash: 'hash',
            actionKey: 'action',
          ),
        );
    container.read(siMemoryProvider.notifier).clear();

    expect(container.read(siMemoryProvider).entries, isEmpty);
    expect(container.read(latestSiSnapshotProvider), isNull);
  });
}
