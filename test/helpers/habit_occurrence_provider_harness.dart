import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/adapters/habit_occurrence_sync_adapter.dart';
import 'package:fantastic_guacamole/data/adapters/habit_occurrence_timeline_adapter.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/repositories/habit_occurrence_repository.dart';
import 'package:fantastic_guacamole/data/repositories/habit_repository.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/services/habit_occurrence_reminder_adapter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fantastic_guacamole/data/sync/sync_mutation_dispatcher.dart';
import 'package:fantastic_guacamole/data/sync/sync_operation.dart';
import 'package:fantastic_guacamole/data/sync/sync_queue_store.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/state/providers/supabase_sync_queue_provider.dart';
import 'fake_reminder_orchestrator_service.dart';
import 'real_hive_test_fixture.dart';
import 'recording_sync_apply.dart';

class HabitOccurrenceProviderHarness {
  HabitOccurrenceProviderHarness._(
    this.scope,
    this.store,
    this.habits,
    this.occurrences,
    this.timeline,
    this.sync,
    this.realHiveFixture,
    this._ownsRealHiveFixture,
    this.queueStorage,
    this.queueStore,
    this._reminder,
    this.reminders,
    this.container,
  );

  factory HabitOccurrenceProviderHarness.accountA({
    HabitOccurrenceHarnessStore? store,
  }) => HabitOccurrenceProviderHarness.authenticated(
    'habit-fixture-a',
    store: store,
  );

  static Future<HabitOccurrenceProviderHarness> accountAWithRealQueue({
    HabitOccurrenceHarnessStore? store,
    RealHiveTestFixture? realHiveFixture,
    RecordingSyncApply? apply,
  }) async {
    final bool ownsRealHiveFixture = realHiveFixture == null;
    final RealHiveTestFixture fixture =
        realHiveFixture ?? await RealHiveTestFixture.create();
    return HabitOccurrenceProviderHarness._create(
      AccountStorageScope.authenticated('habit-fixture-a'),
      store ?? HabitOccurrenceHarnessStore(),
      realHiveFixture: fixture,
      ownsRealHiveFixture: ownsRealHiveFixture,
      apply: apply,
    );
  }

  factory HabitOccurrenceProviderHarness.accountB({
    HabitOccurrenceHarnessStore? store,
  }) => HabitOccurrenceProviderHarness.authenticated(
    'habit-fixture-b',
    store: store,
  );

  factory HabitOccurrenceProviderHarness.authenticated(
    String userId, {
    HabitOccurrenceHarnessStore? store,
  }) => HabitOccurrenceProviderHarness._create(
    AccountStorageScope.authenticated(userId),
    store ?? HabitOccurrenceHarnessStore(),
  );

  factory HabitOccurrenceProviderHarness.signedOut({
    HabitOccurrenceHarnessStore? store,
  }) => HabitOccurrenceProviderHarness._create(
    const AccountStorageScope.signedOut(),
    store ?? HabitOccurrenceHarnessStore(),
  );

  factory HabitOccurrenceProviderHarness._create(
    AccountStorageScope scope,
    HabitOccurrenceHarnessStore store, {
    RealHiveTestFixture? realHiveFixture,
    bool ownsRealHiveFixture = false,
    RecordingSyncApply? apply,
  }
  ) {
    final _Habits habits = _Habits(scope, store);
    final _Occurrences occurrences = _Occurrences(scope, store);
    final _Timeline timeline = _Timeline(scope, store);
    final _Sync sync = _Sync(scope, store);
    final HiveStorage<String>? queueStorage = realHiveFixture == null
        ? null
        : HiveStorage<String>(
            HiveBoxes.accountScoped(HiveBoxes.offlineQueue, scope),
            hive: realHiveFixture.hiveStore,
          );
    final SyncQueueStore? queueStore = queueStorage == null
        ? null
        : SyncQueueStore(queueStorage, storageScope: scope);
    final _Reminder reminder = _Reminder();
    final FakeReminderOrchestratorService reminders =
        FakeReminderOrchestratorService(scope);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWith((Ref ref) => scope),
        habitRepositoryProvider.overrideWithValue(habits),
        habitOccurrenceRepositoryProvider.overrideWithValue(occurrences),
        habitOccurrenceTimelineAdapterProvider.overrideWithValue(timeline),
        if (queueStore != null)
          syncQueueStoreProvider.overrideWithValue(queueStore)
        else
          habitOccurrenceSyncAdapterProvider.overrideWithValue(sync),
        if (apply != null) supabaseSyncApplyProvider.overrideWithValue(apply.apply),
        habitOccurrenceReminderAdapterProvider.overrideWithValue(reminder),
        reminderOrchestratorServiceProvider.overrideWithValue(reminders),
      ],
    );
    return HabitOccurrenceProviderHarness._(
      scope,
      store,
      habits,
      occurrences,
      timeline,
      sync,
      realHiveFixture,
      ownsRealHiveFixture,
      queueStorage,
      queueStore,
      reminder,
      reminders,
      container,
    );
  }

  final AccountStorageScope scope;
  final HabitOccurrenceHarnessStore store;
  final HabitRepository habits;
  final HabitOccurrenceRepository occurrences;
  final HabitOccurrenceTimelineAdapter timeline;
  final HabitOccurrenceSyncAdapter sync;
  final RealHiveTestFixture? realHiveFixture;
  final bool _ownsRealHiveFixture;
  final HiveStorage<String>? queueStorage;
  final SyncQueueStore? queueStore;
  final _Reminder _reminder;
  final FakeReminderOrchestratorService reminders;
  final ProviderContainer container;

  List<HabitOccurrence> get timelineOccurrences => scope.isAuthenticated
      ? List<HabitOccurrence>.unmodifiable((timeline as _Timeline).values)
      : const <HabitOccurrence>[];
  List<HabitOccurrence> get syncOccurrences => scope.isAuthenticated
      ? List<HabitOccurrence>.unmodifiable((sync as _Sync).values)
      : const <HabitOccurrence>[];
  List<HabitOccurrence> get reminderOccurrences =>
      List<HabitOccurrence>.unmodifiable(_reminder.values);
  Future<List<SyncOperation>> queueItems() =>
      (queueStore ?? (throw StateError('This harness does not use a real queue.')))
          .readAll();
  Future<List<SyncOperation>> pendingQueueItems() => queueItems();
  Future<SyncOperation?> queueItemForRecordId(String recordId) async {
    for (final SyncOperation operation in await queueItems()) {
      if (operation.recordId == recordId) return operation;
    }
    return null;
  }
  Future<int> queueCount() async => (await queueItems()).length;
  Future<void> flushSyncQueue() =>
      container.read(supabaseSyncRunnerProvider).runOnce();

  Future<void> seed(HabitRecord habit) =>
      habits.saveHabits(<HabitRecord>[habit]);
  Future<void> replaceHabit(HabitRecord habit) async {
    await habits.saveHabits(<HabitRecord>[habit]);
    container.invalidate(habitsProvider);
    await ready();
  }
  Future<void> ready() async => container.read(habitsProvider.future);
  Future<HabitOccurrenceMutation> complete(String id, DateTime at) => container
      .read(habitsProvider.notifier)
      .completeHabitOccurrence(id, at: at);
  Future<HabitOccurrenceMutation> skip(String id, DateTime at) =>
      container.read(habitsProvider.notifier).skipHabitOccurrence(id, at: at);
  Future<void> dispose() async {
    container.dispose();
    if (_ownsRealHiveFixture) await realHiveFixture?.dispose();
  }
}

class HabitOccurrenceHarnessStore {
  final Map<String, List<HabitRecord>> _habits = <String, List<HabitRecord>>{};
  final Map<String, List<HabitOccurrence>> _occurrences =
      <String, List<HabitOccurrence>>{};
  final Map<String, List<HabitOccurrence>> _timeline =
      <String, List<HabitOccurrence>>{};
  final Map<String, List<HabitOccurrence>> _sync =
      <String, List<HabitOccurrence>>{};

  bool failOccurrenceRead = false;
  bool failOccurrenceWrite = false;
  bool failTimeline = false;
  bool failSync = false;

  String keyFor(AccountStorageScope scope) =>
      scope.isAuthenticated && scope.v2Namespace != null
      ? scope.v2Namespace!
      : (throw StateError(
          'The signed-out test scope has no durable namespace.',
        ));

  List<HabitRecord> habitsFor(AccountStorageScope scope) =>
      _habits.putIfAbsent(keyFor(scope), () => <HabitRecord>[]);
  List<HabitOccurrence> occurrencesFor(AccountStorageScope scope) =>
      _occurrences.putIfAbsent(keyFor(scope), () => <HabitOccurrence>[]);
  List<HabitOccurrence> timelineFor(AccountStorageScope scope) =>
      _timeline.putIfAbsent(keyFor(scope), () => <HabitOccurrence>[]);
  List<HabitOccurrence> syncFor(AccountStorageScope scope) =>
      _sync.putIfAbsent(keyFor(scope), () => <HabitOccurrence>[]);
}

class _Habits extends HabitRepository {
  _Habits(this.scope, this.store) : super.unavailable();
  final AccountStorageScope scope;
  final HabitOccurrenceHarnessStore store;
  List<HabitRecord> get values => store.habitsFor(scope);
  @override
  Future<List<HabitRecord>> getHabits() async => List<HabitRecord>.from(values);
  @override
  Future<void> saveHabits(List<HabitRecord> next) async {
    values
      ..clear()
      ..addAll(next);
  }
}

class _Occurrences extends HabitOccurrenceRepository {
  _Occurrences(this.scope, this.store) : super.unavailable();
  final AccountStorageScope scope;
  final HabitOccurrenceHarnessStore store;
  Future<void> _writeQueue = Future<void>.value();
  List<HabitOccurrence> get values => store.occurrencesFor(scope);

  @override
  Future<List<HabitOccurrence>> listOccurrencesForHabit(String id) async {
    _throwIfReadFails();
    return values
        .where((HabitOccurrence value) => value.habitId == id)
        .toList(growable: false);
  }

  @override
  Future<List<HabitOccurrence>> listOccurrencesForPeriod(
    String id,
    String period,
  ) async {
    _throwIfReadFails();
    return values
        .where(
          (HabitOccurrence value) =>
              value.habitId == id && value.periodKey == period,
        )
        .toList();
  }

  @override
  Future<HabitOccurrence?> getOccurrence(
    String id,
    String period,
    int ordinal,
  ) async {
    _throwIfReadFails();
    return values.cast<HabitOccurrence?>().firstWhere(
      (HabitOccurrence? value) =>
          value?.habitId == id &&
          value?.periodKey == period &&
          value?.ordinal == ordinal,
      orElse: () => null,
    );
  }

  @override
  Future<HabitOccurrenceMutation> completeOccurrence({
    required String habitId,
    required String periodKey,
    required int ordinal,
    required int targetCount,
    DateTime? at,
  }) => _put(
    habitId,
    periodKey,
    ordinal,
    targetCount,
    HabitOccurrenceStatus.completed,
    at ?? DateTime.now(),
  );
  @override
  Future<HabitOccurrenceMutation> skipOccurrence({
    required String habitId,
    required String periodKey,
    required int ordinal,
    required int targetCount,
    DateTime? at,
  }) => _put(
    habitId,
    periodKey,
    ordinal,
    targetCount,
    HabitOccurrenceStatus.skipped,
    at ?? DateTime.now(),
  );
  Future<HabitOccurrenceMutation> _put(
    String id,
    String period,
    int ordinal,
    int target,
    HabitOccurrenceStatus status,
    DateTime at,
  ) {
    final Completer<HabitOccurrenceMutation> result =
        Completer<HabitOccurrenceMutation>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        result.complete(
          await _putSerialized(id, period, ordinal, target, status, at),
        );
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<HabitOccurrenceMutation> _putSerialized(
    String id,
    String period,
    int ordinal,
    int target,
    HabitOccurrenceStatus status,
    DateTime at,
  ) async {
    _throwIfReadFails();
    if (store.failOccurrenceWrite) {
      throw StateError('Injected occurrence write failure.');
    }
    final HabitOccurrence? existing = await getOccurrence(id, period, ordinal);
    if (existing != null) {
      return existing.status == status
          ? HabitOccurrenceMutation.idempotent
          : HabitOccurrenceMutation.conflict;
    }
    values.add(
      HabitOccurrence(
        habitId: id,
        periodKey: period,
        ordinal: ordinal,
        status: status,
        completedAt: status == HabitOccurrenceStatus.completed ? at : null,
        skippedAt: status == HabitOccurrenceStatus.skipped ? at : null,
      ),
    );
    return HabitOccurrenceMutation.inserted;
  }

  void _throwIfReadFails() {
    if (store.failOccurrenceRead) {
      throw StateError('Injected occurrence read failure.');
    }
  }
}

class _Timeline extends HabitOccurrenceTimelineAdapter {
  _Timeline(this.scope, this.store) : super(_UnusedTimeline());
  final AccountStorageScope scope;
  final HabitOccurrenceHarnessStore store;
  List<HabitOccurrence> get values => store.timelineFor(scope);
  @override
  Future<void> record(HabitOccurrence value) async {
    if (store.failTimeline) {
      throw StateError('Injected timeline failure.');
    }
    if (!values.any(
      (HabitOccurrence x) => x.id == value.id && x.status == value.status,
    )) {
      values.add(value);
    }
  }
}

class _Sync extends HabitOccurrenceSyncAdapter {
  _Sync(this.scope, this.store)
    : super(SyncMutationDispatcher(queueStore: _Queue(), userId: 'fixture'));
  final AccountStorageScope scope;
  final HabitOccurrenceHarnessStore store;
  List<HabitOccurrence> get values => store.syncFor(scope);
  @override
  Future<bool> enqueue(HabitOccurrence value) async {
    if (store.failSync) {
      throw StateError('Injected sync enqueue failure.');
    }
    if (!values.any(
      (HabitOccurrence x) => x.id == value.id && x.status == value.status,
    )) {
      values.add(value);
    }
    return true;
  }
}

class _Reminder extends HabitOccurrenceReminderAdapter {
  final List<HabitOccurrence> values = <HabitOccurrence>[];

  @override
  Future<void> reconcile(HabitOccurrence occurrence) async {
    if (!values.any(
      (HabitOccurrence value) =>
          value.id == occurrence.id && value.status == occurrence.status,
    )) {
      values.add(occurrence);
    }
  }
}

class _UnusedTimeline implements ITimelineRepository {
  @override
  Future<void> addEvent(TimelineEventEntity event) async {}
  @override
  List<TimelineEventEntity> getEvents() => const <TimelineEventEntity>[];
  @override
  Future<void> removeEvent(String id) async {}
  @override
  Future<void> saveEvents(List<TimelineEventEntity> events) async {}
}

class _Queue implements SyncQueueStoreContract {
  @override
  Future<void> enqueue(SyncOperation operation) async {}
  @override
  Future<void> overwrite(List<SyncOperation> operations) async {}
  @override
  Future<List<SyncOperation>> readAll() async => const <SyncOperation>[];
  @override
  Future<void> removeById(String id) async {}
  @override
  Future<void> update(SyncOperation updated) async {}
}
