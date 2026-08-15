import 'package:fantastic_guacamole/data/sync/sync_operation.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/data/repositories/habit_occurrence_repository.dart';
import 'package:fantastic_guacamole/data/repositories/habit_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/habit_occurrence_provider_harness.dart';
import '../../helpers/real_hive_test_fixture.dart';
import '../../helpers/recording_sync_apply.dart';

void main() {
  test('real runner applies a completed occurrence once and drains its queue', () async {
    final RecordingSyncApply apply = RecordingSyncApply();
    final HabitOccurrenceProviderHarness harness =
        await HabitOccurrenceProviderHarness.accountAWithRealQueue(apply: apply);
    addTearDown(harness.dispose);
    await harness.seed(const HabitRecord(
      id: 'complete',
      title: 'Complete',
      cadence: HabitCadence.daily,
    ));
    await harness.ready();
    final HabitOccurrenceMutation result = await harness.complete(
      'complete',
      DateTime.utc(2026, 8, 15),
    );
    expect(result, HabitOccurrenceMutation.inserted);
    final HabitOccurrence occurrence =
        (await harness.occurrences.listOccurrencesForHabit('complete')).single;
    expect(harness.timelineOccurrences, contains(same(occurrence)));
    expect(await harness.queueCount(), 1);

    await harness.flushSyncQueue();
    expect(apply.calls, hasLength(1));
    final SyncOperation operation = apply.calls.single;
    expect(operation.tableName, 'habit_occurrences');
    expect(operation.recordId, occurrence.id);
    expect(operation.userId, 'habit-fixture-a');
    expect(operation.payload['status'], 'completed');
    expect(operation.payload['user_id'], 'habit-fixture-a');
    expect(await harness.queueCount(), 0);

    await harness.flushSyncQueue();
    expect(apply.calls, hasLength(1));
    expect(await harness.occurrences.listOccurrencesForHabit('complete'), hasLength(1));
    expect(harness.timelineOccurrences, hasLength(1));
  });

  test('remote failure retains one canonical queued occurrence for retry', () async {
    final RecordingSyncApply apply = RecordingSyncApply(
      mode: RecordingSyncApplyMode.retryableFailure,
    );
    final HabitOccurrenceProviderHarness harness =
        await HabitOccurrenceProviderHarness.accountAWithRealQueue(apply: apply);
    addTearDown(harness.dispose);
    await harness.seed(const HabitRecord(id: 'retry', title: 'Retry'));
    await harness.ready();
    await harness.complete('retry', DateTime.utc(2026, 8, 15));
    final HabitOccurrence occurrence =
        (await harness.occurrences.listOccurrencesForHabit('retry')).single;

    await harness.flushSyncQueue();
    expect(apply.calls, hasLength(1));
    final SyncOperation failed = (await harness.queueItems()).single;
    expect(failed.recordId, occurrence.id);
    expect(failed.retryCount, 1);
    expect(failed.lastError, 'Injected remote apply failure.');
    expect(failed.nextRetryAtUtc, isNotNull);
    expect(await harness.occurrences.listOccurrencesForHabit('retry'), hasLength(1));
    expect(harness.timelineOccurrences, hasLength(1));

    apply.mode = RecordingSyncApplyMode.success;
    await Future<void>.delayed(const Duration(seconds: 2));
    await harness.flushSyncQueue();
    expect(apply.calls, hasLength(2));
    expect(await harness.queueCount(), 0);
    expect(await harness.occurrences.listOccurrencesForHabit('retry'), hasLength(1));
    expect(harness.timelineOccurrences, hasLength(1));
  });

  test('real runner applies skipped occurrences with only Account A identity', () async {
    final RecordingSyncApply apply = RecordingSyncApply();
    final HabitOccurrenceProviderHarness harness =
        await HabitOccurrenceProviderHarness.accountAWithRealQueue(apply: apply);
    addTearDown(harness.dispose);
    await harness.seed(const HabitRecord(id: 'skip', title: 'Skip'));
    await harness.ready();
    await harness.skip('skip', DateTime.utc(2026, 8, 15));
    final HabitOccurrence occurrence =
        (await harness.occurrences.listOccurrencesForHabit('skip')).single;

    await harness.flushSyncQueue();
    final SyncOperation operation = apply.calls.single;
    expect(operation.recordId, occurrence.id);
    expect(operation.payload['status'], 'skipped');
    expect(operation.userId, 'habit-fixture-a');
    expect(operation.payload['user_id'], 'habit-fixture-a');
    expect(operation.userId, isNot(anyOf('habit-fixture-b', isEmpty)));
  });

  test('failed mutation retries after Account A ProviderContainer recreation', () async {
    final RealHiveTestFixture fixture = await RealHiveTestFixture.create();
    addTearDown(fixture.dispose);
    final HabitOccurrenceHarnessStore store = HabitOccurrenceHarnessStore();
    final RecordingSyncApply failedApply = RecordingSyncApply(
      mode: RecordingSyncApplyMode.retryableFailure,
    );
    final HabitOccurrenceProviderHarness first =
        await HabitOccurrenceProviderHarness.accountAWithRealQueue(
          store: store,
          realHiveFixture: fixture,
          apply: failedApply,
        );
    await first.seed(const HabitRecord(id: 'restart', title: 'Restart'));
    await first.ready();
    await first.complete('restart', DateTime.utc(2026, 8, 15));
    final HabitOccurrence occurrence =
        (await first.occurrences.listOccurrencesForHabit('restart')).single;
    await first.flushSyncQueue();
    expect((await first.queueItems()).single.retryCount, 1);
    await first.dispose();

    final RecordingSyncApply successApply = RecordingSyncApply();
    final HabitOccurrenceProviderHarness restarted =
        await HabitOccurrenceProviderHarness.accountAWithRealQueue(
          store: store,
          realHiveFixture: fixture,
          apply: successApply,
        );
    addTearDown(restarted.dispose);
    await restarted.ready();
    expect(
      await restarted.occurrences.listOccurrencesForHabit('restart'),
      hasLength(1),
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    await restarted.flushSyncQueue();
    expect(successApply.calls, hasLength(1));
    expect(successApply.calls.single.recordId, occurrence.id);
    expect(await restarted.queueCount(), 0);
    expect(
      await restarted.occurrences.listOccurrencesForHabit('restart'),
      hasLength(1),
    );
    expect(restarted.timelineOccurrences, hasLength(1));
  });
}
