import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/adapters/habit_occurrence_sync_adapter.dart';
import 'package:fantastic_guacamole/data/adapters/habit_occurrence_timeline_adapter.dart';
import 'package:fantastic_guacamole/data/repositories/habit_repository.dart';
import 'package:fantastic_guacamole/data/repositories/habit_occurrence_repository.dart';
import 'package:fantastic_guacamole/data/sync/sync_mutation_dispatcher.dart';
import 'package:fantastic_guacamole/data/sync/sync_operation.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import '../../helpers/fake_reminder_orchestrator_service.dart';
import '../../helpers/habit_occurrence_provider_harness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'shared reminder fake records and resets habit synchronization',
    () async {
      final FakeReminderOrchestratorService fake =
          FakeReminderOrchestratorService(
            HabitOccurrenceProviderHarness.accountA().scope,
          );
      await fake.syncHabitReminders(<HabitRecord>[
        const HabitRecord(id: 'h', title: 'H'),
      ]);
      expect(fake.habitSyncCalls, hasLength(1));
      fake.reset();
      expect(fake.habitSyncCalls, isEmpty);
    },
  );

  test(
    'Account A harness resolves real command provider and persists complete and skip',
    () async {
      final HabitOccurrenceProviderHarness harness =
          HabitOccurrenceProviderHarness.accountA();
      addTearDown(harness.dispose);
      await harness.habits.saveHabits(<HabitRecord>[
        const HabitRecord(
          id: 'complete',
          title: 'Complete',
          cadence: HabitCadence.daily,
        ),
        const HabitRecord(id: 'skip', title: 'Skip'),
      ]);
      await harness.ready();
      expect(
        harness.container.read(habitOccurrenceRepositoryProvider),
        same(harness.occurrences),
      );
      expect(
        harness.container.read(habitOccurrenceTimelineAdapterProvider),
        same(harness.timeline),
      );
      expect(
        harness.container.read(habitOccurrenceSyncAdapterProvider),
        same(harness.sync),
      );
      expect(
        harness.container.read(reminderOrchestratorServiceProvider),
        same(harness.reminders),
      );
      final DateTime completedAt = DateTime.utc(2026, 8, 15);
      await harness.complete('complete', completedAt);
      final HabitOccurrence completed =
          (await harness.occurrences.listOccurrencesForHabit(
            'complete',
          )).single;
      expect(completed.status, HabitOccurrenceStatus.completed);
      expect(completed.habitId, 'complete');
      expect(
        completed.periodKey,
        HabitOccurrencePeriodKey.forDate(HabitCadence.daily, completedAt),
      );
      expect(completed.ordinal, 1);
      expect(harness.timelineOccurrences, contains(same(completed)));
      expect(harness.syncOccurrences, contains(same(completed)));
      expect(harness.reminderOccurrences, contains(same(completed)));
      expect(
        harness.container
            .read(habitsProvider)
            .requireValue
            .singleWhere((HabitRecord habit) => habit.id == 'complete')
            .active,
        isTrue,
      );
      final DateTime skippedAt = DateTime.utc(2026, 8, 16);
      await harness.container
          .read(habitsProvider.notifier)
          .skipHabitOccurrence('skip', at: skippedAt);
      final HabitOccurrence skipped =
          (await harness.occurrences.listOccurrencesForHabit('skip')).single;
      expect(skipped.status, HabitOccurrenceStatus.skipped);
      expect(skipped.habitId, 'skip');
      expect(
        skipped.periodKey,
        HabitOccurrencePeriodKey.forDate(HabitCadence.daily, skippedAt),
      );
      expect(skipped.ordinal, 1);
      expect(harness.timelineOccurrences, contains(same(skipped)));
      expect(harness.syncOccurrences, contains(same(skipped)));
      expect(harness.reminderOccurrences, contains(same(skipped)));
      expect(
        harness.container
            .read(habitsProvider)
            .requireValue
            .singleWhere((HabitRecord habit) => habit.id == 'skip')
            .active,
        isTrue,
      );
    },
  );

  test(
    'Account A exercises the real occurrence sync adapter, dispatcher, and Hive queue',
    () async {
      final HabitOccurrenceProviderHarness harness =
          await HabitOccurrenceProviderHarness.accountAWithRealQueue();
      addTearDown(harness.dispose);
      await harness.habits.saveHabits(const <HabitRecord>[
        HabitRecord(
          id: 'queue-complete',
          title: 'Queue complete',
          cadence: HabitCadence.daily,
        ),
        HabitRecord(id: 'queue-skip', title: 'Queue skip'),
      ]);
      await harness.ready();

      expect(
        harness.container.read(syncQueueStoreProvider),
        same(harness.queueStore),
      );
      expect(
        harness.container.read(syncMutationDispatcherProvider),
        isA<SyncMutationDispatcher>(),
      );
      expect(
        harness.container.read(habitOccurrenceSyncAdapterProvider),
        isNot(same(harness.sync)),
      );
      expect(
        harness.container.read(habitOccurrenceSyncAdapterProvider),
        isA<HabitOccurrenceSyncAdapter>(),
      );

      final DateTime at = DateTime.utc(2026, 8, 15);
      expect(
        await harness.complete('queue-complete', at),
        HabitOccurrenceMutation.inserted,
      );
      final HabitOccurrence complete =
          (await harness.occurrences.listOccurrencesForHabit(
            'queue-complete',
          )).single;
      expect(harness.timelineOccurrences, contains(same(complete)));
      expect(harness.reminderOccurrences, contains(same(complete)));

      SyncOperation completeOperation =
          (await harness.queueItemForRecordId(complete.id))!;
      expect(completeOperation.tableName, 'habit_occurrences');
      expect(completeOperation.operationType, SyncOperationType.update);
      expect(completeOperation.userId, 'habit-fixture-a');
      expect(completeOperation.payload['status'], 'completed');
      expect(completeOperation.payload['habit_id'], 'queue-complete');
      expect(completeOperation.payload['period_key'], complete.periodKey);
      expect(completeOperation.payload['ordinal'], complete.ordinal);
      expect(completeOperation.payload['user_id'], 'habit-fixture-a');

      expect(
        await harness.complete('queue-complete', at),
        HabitOccurrenceMutation.idempotent,
      );
      expect(await harness.queueCount(), 1);

      expect(
        await harness.skip('queue-skip', at),
        HabitOccurrenceMutation.inserted,
      );
      final HabitOccurrence skipped =
          (await harness.occurrences.listOccurrencesForHabit('queue-skip')).single;
      expect(harness.timelineOccurrences, contains(same(skipped)));
      expect(harness.reminderOccurrences, contains(same(skipped)));
      final SyncOperation skippedOperation =
          (await harness.queueItemForRecordId(skipped.id))!;
      expect(skippedOperation.tableName, 'habit_occurrences');
      expect(skippedOperation.operationType, SyncOperationType.update);
      expect(skippedOperation.userId, 'habit-fixture-a');
      expect(skippedOperation.payload['status'], 'skipped');
      expect(skippedOperation.payload['habit_id'], 'queue-skip');
      expect(await harness.queueCount(), 2);
    },
  );

  test('duplicate complete and skip are canonical and idempotent', () async {
    final HabitOccurrenceProviderHarness harness =
        HabitOccurrenceProviderHarness.accountA();
    addTearDown(harness.dispose);
    await harness.habits.saveHabits(const <HabitRecord>[
      HabitRecord(id: 'complete', title: 'Complete'),
      HabitRecord(id: 'skip', title: 'Skip'),
    ]);
    await harness.ready();

    final DateTime at = DateTime.utc(2026, 8, 15);
    expect(
      await harness.complete('complete', at),
      HabitOccurrenceMutation.inserted,
    );
    expect(
      await harness.complete('complete', at),
      HabitOccurrenceMutation.idempotent,
    );
    expect(await harness.skip('skip', at), HabitOccurrenceMutation.inserted);
    expect(await harness.skip('skip', at), HabitOccurrenceMutation.idempotent);

    expect(
      await harness.occurrences.listOccurrencesForHabit('complete'),
      hasLength(1),
    );
    expect(
      await harness.occurrences.listOccurrencesForHabit('skip'),
      hasLength(1),
    );
    expect(harness.timelineOccurrences, hasLength(2));
    expect(harness.syncOccurrences, hasLength(2));
    expect(harness.reminderOccurrences, hasLength(2));
  });

  test('complete/skip conflicts preserve one canonical disposition', () async {
    final HabitOccurrenceProviderHarness harness =
        HabitOccurrenceProviderHarness.accountA();
    addTearDown(harness.dispose);
    await harness.habits.saveHabits(const <HabitRecord>[
      HabitRecord(id: 'complete-first', title: 'Complete first'),
      HabitRecord(id: 'skip-first', title: 'Skip first'),
    ]);
    await harness.ready();
    final DateTime at = DateTime.utc(2026, 8, 15);

    expect(
      await harness.complete('complete-first', at),
      HabitOccurrenceMutation.inserted,
    );
    expect(
      await harness.skip('complete-first', at),
      HabitOccurrenceMutation.conflict,
    );
    expect(
      await harness.skip('skip-first', at),
      HabitOccurrenceMutation.inserted,
    );
    expect(
      await harness.complete('skip-first', at),
      HabitOccurrenceMutation.conflict,
    );

    expect(
      (await harness.occurrences.listOccurrencesForHabit(
        'complete-first',
      )).single.status,
      HabitOccurrenceStatus.completed,
    );
    expect(
      (await harness.occurrences.listOccurrencesForHabit(
        'skip-first',
      )).single.status,
      HabitOccurrenceStatus.skipped,
    );
    expect(harness.timelineOccurrences, hasLength(2));
    expect(harness.syncOccurrences, hasLength(2));
  });

  test(
    'concurrent complete and skip emit one disposition and one projection',
    () async {
      final HabitOccurrenceProviderHarness harness =
          HabitOccurrenceProviderHarness.accountA();
      addTearDown(harness.dispose);
      await harness.seed(const HabitRecord(id: 'race', title: 'Race'));
      await harness.ready();
      final DateTime at = DateTime.utc(2026, 8, 15);

      final List<HabitOccurrenceMutation> outcomes = await Future.wait(
        <Future<HabitOccurrenceMutation>>[
          harness.complete('race', at),
          harness.skip('race', at),
        ],
      );
      expect(outcomes, contains(HabitOccurrenceMutation.inserted));
      expect(outcomes, contains(HabitOccurrenceMutation.conflict));
      expect(
        await harness.occurrences.listOccurrencesForHabit('race'),
        hasLength(1),
      );
      expect(harness.timelineOccurrences, hasLength(1));
      expect(harness.syncOccurrences, hasLength(1));
    },
  );

  test(
    'A/B isolation, same-owner reauth, and restart preserve only scoped facts',
    () async {
      final HabitOccurrenceHarnessStore store = HabitOccurrenceHarnessStore();
      final HabitOccurrenceProviderHarness a =
          HabitOccurrenceProviderHarness.accountA(store: store);
      await a.seed(const HabitRecord(id: 'shared', title: 'A habit'));
      await a.ready();
      await a.complete('shared', DateTime.utc(2026, 8, 15));
      expect(a.timelineOccurrences, hasLength(1));

      final HabitOccurrenceProviderHarness b =
          HabitOccurrenceProviderHarness.accountB(store: store);
      addTearDown(b.dispose);
      await b.seed(const HabitRecord(id: 'shared', title: 'B habit'));
      await b.ready();
      expect(await b.occurrences.listOccurrencesForHabit('shared'), isEmpty);
      expect(b.timelineOccurrences, isEmpty);
      expect(b.syncOccurrences, isEmpty);
      await b.skip('shared', DateTime.utc(2026, 8, 15));
      expect(
        (await b.occurrences.listOccurrencesForHabit('shared')).single.status,
        HabitOccurrenceStatus.skipped,
      );
      expect(
        (await a.occurrences.listOccurrencesForHabit('shared')).single.status,
        HabitOccurrenceStatus.completed,
      );

      a.dispose();
      final HabitOccurrenceProviderHarness restartedA =
          HabitOccurrenceProviderHarness.accountA(store: store);
      addTearDown(restartedA.dispose);
      await restartedA.ready();
      expect(
        (await restartedA.occurrences.listOccurrencesForHabit(
          'shared',
        )).single.status,
        HabitOccurrenceStatus.completed,
      );
      expect(restartedA.timelineOccurrences, hasLength(1));
      expect(restartedA.syncOccurrences, hasLength(1));
    },
  );

  test('signed-out provider fails closed without occurrence effects', () async {
    final HabitOccurrenceProviderHarness signedOut =
        HabitOccurrenceProviderHarness.signedOut();
    addTearDown(signedOut.dispose);
    await expectLater(signedOut.ready(), throwsStateError);
    await expectLater(
      signedOut.complete('missing', DateTime.utc(2026, 8, 15)),
      throwsStateError,
    );
    await expectLater(
      signedOut.skip('missing', DateTime.utc(2026, 8, 15)),
      throwsStateError,
    );
    expect(signedOut.timelineOccurrences, isEmpty);
    expect(signedOut.syncOccurrences, isEmpty);
    expect(signedOut.reminderOccurrences, isEmpty);
  });

  test(
    'read/write, timeline, and sync failures retain canonical retry behavior',
    () async {
      final HabitOccurrenceHarnessStore store = HabitOccurrenceHarnessStore();
      final HabitOccurrenceProviderHarness harness =
          HabitOccurrenceProviderHarness.accountA(store: store);
      addTearDown(harness.dispose);
      await harness.habits.saveHabits(const <HabitRecord>[
        HabitRecord(id: 'read', title: 'Read'),
        HabitRecord(id: 'write', title: 'Write'),
        HabitRecord(id: 'timeline', title: 'Timeline'),
        HabitRecord(id: 'sync', title: 'Sync'),
      ]);
      await harness.ready();
      final DateTime at = DateTime.utc(2026, 8, 15);

      store.failOccurrenceRead = true;
      await expectLater(harness.complete('read', at), throwsStateError);
      store.failOccurrenceRead = false;
      store.failOccurrenceWrite = true;
      await expectLater(harness.complete('write', at), throwsStateError);
      store.failOccurrenceWrite = false;
      expect(
        await harness.complete('write', at),
        HabitOccurrenceMutation.inserted,
      );

      store.failTimeline = true;
      await expectLater(harness.complete('timeline', at), throwsStateError);
      store.failTimeline = false;
      expect(
        await harness.complete('timeline', at),
        HabitOccurrenceMutation.idempotent,
      );

      store.failSync = true;
      await expectLater(harness.complete('sync', at), throwsStateError);
      store.failSync = false;
      expect(
        await harness.complete('sync', at),
        HabitOccurrenceMutation.idempotent,
      );

      expect(
        await harness.occurrences.listOccurrencesForHabit('read'),
        isEmpty,
      );
      expect(
        await harness.occurrences.listOccurrencesForHabit('write'),
        hasLength(1),
      );
      expect(
        await harness.occurrences.listOccurrencesForHabit('timeline'),
        hasLength(1),
      );
      expect(
        await harness.occurrences.listOccurrencesForHabit('sync'),
        hasLength(1),
      );
      expect(
        harness.timelineOccurrences.where(
          (HabitOccurrence value) => value.habitId == 'timeline',
        ),
        hasLength(1),
      );
      expect(
        harness.syncOccurrences.where(
          (HabitOccurrence value) => value.habitId == 'sync',
        ),
        hasLength(1),
      );
    },
  );

  test(
    'same-owner reauth restores one prior occurrence without replay',
    () async {
      final HabitOccurrenceHarnessStore store = HabitOccurrenceHarnessStore();
      final HabitOccurrenceProviderHarness a =
          HabitOccurrenceProviderHarness.accountA(store: store);
      await a.seed(const HabitRecord(id: 'reauth', title: 'Reauth'));
      await a.ready();
      await a.complete('reauth', DateTime.utc(2026, 8, 15));
      a.dispose();
      final HabitOccurrenceProviderHarness signedOut =
          HabitOccurrenceProviderHarness.signedOut(store: store);
      addTearDown(signedOut.dispose);
      await expectLater(signedOut.ready(), throwsStateError);
      final HabitOccurrenceProviderHarness returned =
          HabitOccurrenceProviderHarness.accountA(store: store);
      addTearDown(returned.dispose);
      await returned.ready();
      expect(
        await returned.occurrences.listOccurrencesForHabit('reauth'),
        hasLength(1),
      );
      expect(returned.timelineOccurrences, hasLength(1));
      expect(returned.syncOccurrences, hasLength(1));
      expect(returned.reminderOccurrences, isEmpty);
    },
  );

  test(
    'stale A repository and adapters remain A-bound after B constructs',
    () async {
      final HabitOccurrenceHarnessStore store = HabitOccurrenceHarnessStore();
      final HabitOccurrenceProviderHarness a =
          HabitOccurrenceProviderHarness.accountA(store: store);
      await a.seed(const HabitRecord(id: 'shared', title: 'A'));
      await a.ready();
      final HabitOccurrenceRepository staleRepository = a.occurrences;
      final HabitOccurrenceTimelineAdapter staleTimeline = a.timeline;
      final HabitOccurrenceSyncAdapter staleSync = a.sync;
      await a.complete('shared', DateTime.utc(2026, 8, 15));
      final HabitOccurrenceProviderHarness b =
          HabitOccurrenceProviderHarness.accountB(store: store);
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await b.seed(const HabitRecord(id: 'shared', title: 'B'));
      await b.ready();
      final HabitOccurrence stale =
          (await staleRepository.listOccurrencesForHabit('shared')).single;
      await staleTimeline.record(stale);
      await staleSync.enqueue(stale);
      expect(await b.occurrences.listOccurrencesForHabit('shared'), isEmpty);
      expect(b.timelineOccurrences, isEmpty);
      expect(b.syncOccurrences, isEmpty);
    },
  );

  test('pause/completion orderings preserve valid serialized states', () async {
    final HabitOccurrenceProviderHarness pauseFirst =
        HabitOccurrenceProviderHarness.accountA();
    addTearDown(pauseFirst.dispose);
    await pauseFirst.seed(
      const HabitRecord(id: 'pause-first', title: 'Pause first'),
    );
    await pauseFirst.ready();
    await pauseFirst.container
        .read(habitsProvider.notifier)
        .toggleHabit('pause-first');
    await expectLater(
      pauseFirst.complete('pause-first', DateTime.utc(2026, 8, 15)),
      throwsStateError,
    );
    expect(
      await pauseFirst.occurrences.listOccurrencesForHabit('pause-first'),
      isEmpty,
    );

    final HabitOccurrenceProviderHarness completeFirst =
        HabitOccurrenceProviderHarness.accountA();
    addTearDown(completeFirst.dispose);
    await completeFirst.seed(
      const HabitRecord(id: 'complete-first', title: 'Complete first'),
    );
    await completeFirst.ready();
    await completeFirst.complete('complete-first', DateTime.utc(2026, 8, 15));
    await completeFirst.container
        .read(habitsProvider.notifier)
        .toggleHabit('complete-first');
    expect(
      await completeFirst.occurrences.listOccurrencesForHabit('complete-first'),
      hasLength(1),
    );
    expect(completeFirst.timelineOccurrences, hasLength(1));
    expect(completeFirst.syncOccurrences, hasLength(1));
  });

  test('canonical definition edit before complete preserves both authorities', () async {
    final HabitOccurrenceProviderHarness harness =
        HabitOccurrenceProviderHarness.accountA();
    addTearDown(harness.dispose);
    const HabitRecord original = HabitRecord(
      id: 'edit-first',
      title: 'Original',
      description: 'Original description',
      cadence: HabitCadence.daily,
      targetCount: 1,
    );
    const HabitRecord edited = HabitRecord(
      id: 'edit-first',
      title: 'Edited',
      description: 'Edited description',
      cadence: HabitCadence.weekly,
      targetCount: 3,
    );
    await harness.seed(original);
    await harness.ready();
    await harness.replaceHabit(edited);
    await harness.complete('edit-first', DateTime.utc(2026, 8, 15));

    expect((await harness.habits.getHabits()).single, edited);
    expect(await harness.occurrences.listOccurrencesForHabit('edit-first'), hasLength(1));
    expect(harness.timelineOccurrences, hasLength(1));
    expect(harness.syncOccurrences, hasLength(1));
  });

  test('complete before canonical definition edit preserves both authorities', () async {
    final HabitOccurrenceProviderHarness harness =
        HabitOccurrenceProviderHarness.accountA();
    addTearDown(harness.dispose);
    const HabitRecord original = HabitRecord(
      id: 'complete-first-edit',
      title: 'Original',
      description: 'Original description',
      cadence: HabitCadence.daily,
      targetCount: 1,
    );
    const HabitRecord edited = HabitRecord(
      id: 'complete-first-edit',
      title: 'Edited',
      description: 'Edited description',
      cadence: HabitCadence.weekly,
      targetCount: 3,
    );
    await harness.seed(original);
    await harness.ready();
    await harness.complete('complete-first-edit', DateTime.utc(2026, 8, 15));
    await harness.replaceHabit(edited);

    expect((await harness.habits.getHabits()).single, edited);
    expect(
      await harness.occurrences.listOccurrencesForHabit('complete-first-edit'),
      hasLength(1),
    );
    expect(harness.timelineOccurrences, hasLength(1));
    expect(harness.syncOccurrences, hasLength(1));
  });
}
