import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_log_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/add_log_entry.dart';
import 'package:fantastic_guacamole/domain/usecases/get_logs.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'history hydration started by a goal operation cannot replace the next account',
    () async {
      final repoA = _DelayedLogs()
        ..readResult = Completer<List<LogEntryEntity>>();
      final repoB = _DelayedLogs();
      var activeRepo = repoA;
      final container = ProviderContainer(
        overrides: [getLogsProvider.overrideWith((ref) => GetLogs(activeRepo))],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(logsProvider, (_, _) {});
      addTearDown(subscription.close);
      await pumpEventQueue();
      activeRepo = repoB;
      container.invalidate(getLogsProvider);
      container.invalidate(logsProvider);
      await container.pump();
      await pumpEventQueue();
      repoA.readResult!.complete(<LogEntryEntity>[
        LogEntryEntity(
          id: 'private-a',
          source: 'goal_created',
          message: 'Private A goal',
          timestamp: DateTime.utc(2026, 9, 9),
        ),
      ]);
      await pumpEventQueue();
      expect(container.read(logsProvider).entries, isEmpty);
      expect(container.read(logsProvider).isLoading, isFalse);
    },
  );
  test(
    'goal history finishing after account switch cannot enter new log state',
    () async {
      final repo = _DelayedLogs();
      bool current = true;
      final container = ProviderContainer(
        overrides: [
          addLogEntryProvider.overrideWithValue(AddLogEntry(repo)),
          getLogsProvider.overrideWithValue(GetLogs(repo)),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(logsProvider, (_, _) {});
      addTearDown(subscription.close);
      await pumpEventQueue();
      final write = container
          .read(logsActionsProvider)
          .addMirroredEntry(
            source: 'goal_created',
            message: 'Private A goal',
            shouldContinue: () => current,
          );
      await repo.entered.future;
      current = false;
      container.invalidate(logsProvider);
      await container.pump();
      repo.release.complete();
      await write;
      expect(repo.saved.single.message, 'Private A goal');
      expect(container.read(logsProvider).entries, isEmpty);
    },
  );

  test(
    'goal timeline write finishing after account switch cannot enter B state',
    () async {
      final repoA = _DelayedTimeline();
      final repoB = _DelayedTimeline();
      var scope = AccountStorageScope.authenticated('account-a');
      bool current = true;
      final container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWith((ref) => scope),
          domainTimelineRepositoryProvider.overrideWith(
            (ref) =>
                ref.watch(accountStorageScopeProvider).rawUserId == 'account-a'
                ? repoA
                : repoB,
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(timelineProvider, (_, _) {});
      addTearDown(subscription.close);
      final write = container
          .read(timelineActionsProvider)
          .addMirroredEvent(
            TimelineEventEntity(
              id: 'private-a',
              type: TimelineEventType.reflection,
              title: 'Goal created',
              detail: 'Private A goal',
              timestamp: DateTime.utc(2026, 9, 9),
            ),
            shouldContinue: () => current,
          );
      await repoA.entered.future;
      current = false;
      scope = AccountStorageScope.authenticated('account-b');
      container.invalidate(accountStorageScopeProvider);
      await container.pump();
      repoA.release.complete();
      await write;
      expect(repoA.events.single.detail, 'Private A goal');
      expect(repoB.events, isEmpty);
      expect(container.read(timelineProvider), isEmpty);
    },
  );

  for (final bool blockHydration in <bool>[true, false]) {
    test(
      'goal XP cannot cross accounts during ${blockHydration ? 'hydration' : 'save'}',
      () async {
        final backend = _DelayedProfileBackend(blockHydration: blockHydration);
        var scope = AccountStorageScope.authenticated('account-a');
        bool current = true;
        final container = ProviderContainer(
          overrides: [
            accountStorageScopeProvider.overrideWith((ref) => scope),
            accountLegacyOwnershipProvider.overrideWithValue(
              LegacyScopeOwnership.provenNotOwned,
            ),
            secureStoreProvider.overrideWithValue(
              SecureStore(backend: backend),
            ),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(profileProvider, (_, _) {});
        addTearDown(subscription.close);
        final award = container
            .read(profileProvider.notifier)
            .awardXP(12, source: 'goal_created', shouldContinue: () => current);
        await backend.entered.future;
        current = false;
        scope = AccountStorageScope.authenticated('account-b');
        container.invalidate(accountStorageScopeProvider);
        await container.pump();
        await pumpEventQueue();
        expect(container.read(profileProvider).xp, 900);
        backend.release.complete();
        await award;
        await pumpEventQueue();
        expect(container.read(profileProvider).xp, 900);
        expect(container.read(profileProvider).name, 'Account B');
        expect(container.read(profileProvider).xpBySource, isEmpty);
        expect(backend.writes.where((key) => key == backend.keyB), isEmpty);
        if (blockHydration) expect(backend.writes, isEmpty);
      },
    );
  }
}

class _DelayedLogs implements ILogRepository {
  Completer<List<LogEntryEntity>>? readResult;
  final entered = Completer<void>();
  final release = Completer<void>();
  final saved = <LogEntryEntity>[];
  @override
  Future<List<LogEntryEntity>> getLogs() async =>
      readResult == null ? <LogEntryEntity>[] : await readResult!.future;
  @override
  Future<void> addLog(LogEntryEntity entry) async {
    entered.complete();
    await release.future;
    saved.add(entry);
  }
}

class _DelayedTimeline implements ITimelineRepository {
  final entered = Completer<void>();
  final release = Completer<void>();
  final events = <TimelineEventEntity>[];
  @override
  bool get lastReadCorrupted => false;
  @override
  List<TimelineEventEntity> getEvents() => List.unmodifiable(events);
  @override
  Future<void> addEvent(TimelineEventEntity event) async {
    entered.complete();
    await release.future;
    events.add(event);
  }

  @override
  Future<void> saveEvents(List<TimelineEventEntity> value) async => events
    ..clear()
    ..addAll(value);
  @override
  Future<void> removeEvent(String id) async =>
      events.removeWhere((e) => e.id == id);
}

class _DelayedProfileBackend implements SecureStoreBackend {
  _DelayedProfileBackend({required this.blockHydration});
  final bool blockHydration;
  final entered = Completer<void>();
  final release = Completer<void>();
  final writes = <String>[];
  final String keyA = AccountStorageNamespace.authenticated(
    'account-a',
  ).scopedKey('profile_state_v2');
  final String keyB = AccountStorageNamespace.authenticated(
    'account-b',
  ).scopedKey('profile_state_v2');

  @override
  Future<String?> read({required String key}) async {
    if (key == keyA) {
      if (blockHydration) {
        entered.complete();
        await release.future;
      }
      return jsonEncode(ProfileState(name: 'Account A', xp: 100).toJson());
    }
    if (key == keyB) {
      return jsonEncode(ProfileState(name: 'Account B', xp: 900).toJson());
    }
    return null;
  }

  @override
  Future<void> write({required String key, required String value}) async {
    writes.add(key);
    if (!blockHydration && key == keyA) {
      entered.complete();
      await release.future;
    }
  }

  @override
  Future<void> delete({required String key}) async {}
  @override
  Future<void> deleteAll() async {}
  @override
  Future<Map<String, String>> readAll() async => <String, String>{};
}
