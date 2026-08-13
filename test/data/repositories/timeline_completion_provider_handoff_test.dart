import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/repositories/completion_event_repository.dart';
import 'package:fantastic_guacamole/data/repositories/timeline_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/completion_event_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/completion_events_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/timeline_misc_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryPrefs implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => values[key];

  @override
  Future<void> save(String key, String value) async {
    values[key] = value;
  }
}

TimelineEventEntity _timelineEvent(String id, String title) =>
    TimelineEventEntity(
      id: id,
      type: TimelineEventType.task,
      title: title,
      detail: title,
      timestamp: DateTime.utc(2026, 8, 13),
    );

CompletionEventEntity _completionEvent(String id, String userId) =>
    CompletionEventEntity(
      id: id,
      taskId: 'task-$id',
      userId: userId,
      eventType: CompletionEventType.completed,
      eventAt: DateTime.utc(2026, 8, 13),
    );

void main() {
  test(
    'PRE-TEST-02B providers recreate repositories and preserve A→B→A isolation',
    () async {
      final _MemoryPrefs store = _MemoryPrefs();
      AccountStorageScope currentScope = AccountStorageScope.authenticated(
        'account-a',
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          sensitivePrefsStoreProvider.overrideWithValue(store),
          accountStorageScopeProvider.overrideWith((Ref ref) => currentScope),
        ],
      );
      addTearDown(container.dispose);

      void transitionTo(AccountStorageScope nextScope) {
        currentScope = nextScope;
        container.invalidate(accountStorageScopeProvider);
        // These are the exact repository invalidations owned by FIX-004A3.
        container.invalidate(timelineRepositoryProvider);
        container.invalidate(completionEventRepositoryProvider);
      }

      final TimelineRepository timelineA = container.read(
        timelineRepositoryProvider,
      );
      final CompletionEventRepository completionA = container.read(
        completionEventRepositoryProvider,
      );
      await timelineA.addEvent(_timelineEvent('same-id', 'A timeline'));
      await completionA.addEvent(_completionEvent('same-id', 'account-a'));

      transitionTo(AccountStorageScope.authenticated('account-b'));
      final TimelineRepository timelineB = container.read(
        timelineRepositoryProvider,
      );
      final CompletionEventRepository completionB = container.read(
        completionEventRepositoryProvider,
      );

      expect(identical(timelineA, timelineB), isFalse);
      expect(identical(completionA, completionB), isFalse);
      expect(timelineB.getEvents(), isEmpty);
      expect(completionB.getEvents(), isEmpty);
      await timelineB.addEvent(_timelineEvent('same-id', 'B timeline'));
      await completionB.addEvent(_completionEvent('same-id', 'account-b'));

      transitionTo(AccountStorageScope.authenticated('account-a'));
      final TimelineRepository timelineAAgain = container.read(
        timelineRepositoryProvider,
      );
      final CompletionEventRepository completionAAgain = container.read(
        completionEventRepositoryProvider,
      );

      expect(identical(timelineB, timelineAAgain), isFalse);
      expect(identical(completionB, completionAAgain), isFalse);
      expect(timelineAAgain.getEvents().single.title, 'A timeline');
      expect(completionAAgain.getEvents().single.userId, 'account-a');
      expect(timelineB.getEvents().single.title, 'B timeline');
      expect(completionB.getEvents().single.userId, 'account-b');
    },
  );

  test(
    'PRE-TEST-02C SI dependencies and completion read context exclude A after A→B',
    () async {
      final _MemoryPrefs store = _MemoryPrefs();
      AccountStorageScope currentScope = AccountStorageScope.authenticated(
        'account-a',
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          sensitivePrefsStoreProvider.overrideWithValue(store),
          accountStorageScopeProvider.overrideWith((Ref ref) => currentScope),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(timelineRepositoryProvider)
          .addEvent(_timelineEvent('a-timeline', 'A timeline'));
      await container
          .read(completionEventRepositoryProvider)
          .addEvent(_completionEvent('a-completion', 'account-a'));
      expect(
        container.read(siEngineDependenciesProvider).timeline.getEvents(),
        hasLength(1),
      );
      expect(container.read(completionEventsProvider), hasLength(1));

      currentScope = AccountStorageScope.authenticated('account-b');
      container.invalidate(accountStorageScopeProvider);
      container.invalidate(timelineRepositoryProvider);
      container.invalidate(completionEventRepositoryProvider);
      container.invalidate(siEngineDependenciesProvider);
      container.invalidate(completionEventsProvider);

      expect(
        container.read(siEngineDependenciesProvider).timeline.getEvents(),
        isEmpty,
      );
      expect(container.read(completionEventsProvider), isEmpty);
    },
  );

  test(
    'PRE-TEST-02C Timeline read context excludes A after the exact A3 invalidations',
    () async {
      final _MemoryPrefs store = _MemoryPrefs();
      AccountStorageScope currentScope = AccountStorageScope.authenticated(
        'account-a',
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          sensitivePrefsStoreProvider.overrideWithValue(store),
          accountStorageScopeProvider.overrideWith((Ref ref) => currentScope),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(timelineRepositoryProvider)
          .addEvent(_timelineEvent('a-timeline', 'A timeline'));
      final Object viewA = container.read(viewTimelineUsecaseProvider);
      expect(container.read(timelineProvider).single.title, 'A timeline');

      currentScope = AccountStorageScope.authenticated('account-b');
      container.invalidate(accountStorageScopeProvider);
      container.invalidate(timelineRepositoryProvider);
      container.invalidate(viewTimelineUsecaseProvider);
      container.invalidate(timelineProvider);

      final Object viewB = container.read(viewTimelineUsecaseProvider);
      expect(identical(viewA, viewB), isFalse);
      expect(container.read(timelineProvider), isEmpty);
    },
  );
}
