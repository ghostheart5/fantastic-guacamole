import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/adapters/task_occurrence_completion_adapter.dart';
import 'package:fantastic_guacamole/data/adapters/task_occurrence_sync_adapter.dart';
import 'package:fantastic_guacamole/data/adapters/task_occurrence_timeline_adapter.dart';
import 'package:fantastic_guacamole/data/repositories/task_occurrence_projection_work_repository.dart';
import 'package:fantastic_guacamole/data/repositories/task_occurrence_repository.dart';
import 'package:fantastic_guacamole/data/storage/neural_history_store.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/sync/sync_mutation_dispatcher.dart';
import 'package:fantastic_guacamole/data/sync/sync_operation.dart';
import 'package:fantastic_guacamole/data/sync/sync_queue_store.dart';
import 'package:fantastic_guacamole/domain/entities/completion_event_entity.dart';
import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_completion_event_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart'
    show authUserProvider;
import 'package:fantastic_guacamole/state/providers/auth_session_lifecycle_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/services/task_occurrence_downstream_adapters.dart';
import 'package:fantastic_guacamole/state/services/task_occurrence_projection_coordinator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_session_lifecycle_integration_fixture.dart';

class _Timeline implements ITimelineRepository {
  @override
  Future<void> addEvent(TimelineEventEntity event) async {}
  @override
  List<TimelineEventEntity> getEvents() => const <TimelineEventEntity>[];
  @override
  Future<void> removeEvent(String id) async {}
  @override
  Future<void> saveEvents(List<TimelineEventEntity> events) async {}
}

class _Completion implements ICompletionEventRepository {
  @override
  Future<void> addEvent(CompletionEventEntity event) async {}
  @override
  List<CompletionEventEntity> getEvents() => const <CompletionEventEntity>[];
  @override
  Future<void> removeEvent(String id) async {}
  @override
  Future<void> saveEvents(List<CompletionEventEntity> events) async {}
}

class _Queue implements SyncQueueStoreContract {
  @override
  Future<void> enqueue(SyncOperation operation) async {}
  @override
  Future<void> overwrite(List<SyncOperation> operations) async {}
  @override
  Future<List<SyncOperation>> readAll() async => const <SyncOperation>[];
  @override
  Future<void> removeById(String operationId) async {}
  @override
  Future<void> update(SyncOperation updated) async {}
}

class _BlockingProjection extends TaskOccurrenceProjectionCoordinator {
  _BlockingProjection()
    : super(
        scope: AccountStorageScope.authenticated('lifecycle-owner-a'),
        timeline: TaskOccurrenceTimelineAdapter(_Timeline()),
        completion: TaskOccurrenceCompletionAdapter(_Completion()),
        sync: TaskOccurrenceSyncAdapter(
          SyncMutationDispatcher(
            queueStore: _Queue(),
            userId: 'lifecycle-owner-a',
          ),
        ),
        workRepository: TaskOccurrenceProjectionWorkRepository.unavailable(),
        occurrenceRepository: TaskOccurrenceRepository.unavailable(),
        learning: TaskOccurrenceLearningAdapter(
          ({required bool success, required int difficulty}) async {},
        ),
        log: TaskOccurrenceLogAdapter((LogEntryEntity entry) async {}),
        neural: TaskOccurrenceNeuralAdapter(
          NeuralHistoryStore(
            scope: AccountStorageScope.authenticated('lifecycle-owner-a'),
            secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
          ),
        ),
      );
  final Completer<void> started = Completer<void>();
  final Completer<void> release = Completer<void>();
  bool armed = false;
  @override
  Future<void> cancelAndDrain() async {
    if (!armed) return;
    if (!started.isCompleted) started.complete();
    await release.future;
  }
}

void main() {
  test(
    'real coordinator signs the owning account out in lifecycle order',
    () async {
      final fixture = AuthSessionLifecycleIntegrationFixture();
      final container = await fixture.createContainer();
      addTearDown(container.dispose);

      fixture.auth.user = fixture.user('lifecycle-owner-a');
      final coordinator = container.read(authSessionLifecycleProvider);
      await coordinator.initialize(fixture.auth.user);
      expect(
        container.read(authSessionBoundaryProvider).userId,
        'lifecycle-owner-a',
      );
      expect(
        container.read(authSessionBoundaryProvider).isTransitioning,
        isFalse,
      );
      expect(container.read(authSessionBoundaryProvider).blockingIssue, isNull);

      fixture.auth.user = null;
      await coordinator.synchronize(null);

      expect(container.read(authSessionBoundaryProvider).userId, isNull);
      expect(
        container.read(authSessionBoundaryProvider).isTransitioning,
        isFalse,
      );
      expect(container.read(authSessionBoundaryProvider).blockingIssue, isNull);
      expect(fixture.notificationPlatformCalls, contains('cancelAll'));
      expect(
        fixture.events,
        containsAllInOrder(<String>[
          'suspend_writes',
          'cancel_and_drain',
          'invalidate',
          'identity_handoff',
          'boundary_ready',
        ]),
      );
    },
  );

  test(
    'real coordinator supports owning A sign-out then same-owner reauthentication',
    () async {
      final fixture = AuthSessionLifecycleIntegrationFixture();
      final container = await fixture.createContainer();
      addTearDown(container.dispose);
      final coordinator = container.read(authSessionLifecycleProvider);

      fixture.auth.user = fixture.user('lifecycle-owner-a');
      await coordinator.initialize(fixture.auth.user);
      fixture.auth.user = null;
      await coordinator.synchronize(null);
      expect(container.read(authSessionBoundaryProvider).userId, isNull);
      expect(await fixture.readOwnerMarker(), 'user:lifecycle-owner-a');

      fixture.auth.user = fixture.user('lifecycle-owner-a');
      await coordinator.synchronize(fixture.auth.user);

      final boundary = container.read(authSessionBoundaryProvider);
      expect(boundary.userId, 'lifecycle-owner-a');
      expect(boundary.isStorageReady, isTrue);
      expect(boundary.blockingIssue, isNull);
      expect(fixture.events, contains('resume_writes'));
    },
  );

  test(
    'real coordinator rejects B after A has signed out and retained ownership',
    () async {
      final fixture = AuthSessionLifecycleIntegrationFixture();
      final container = await fixture.createContainer();
      addTearDown(container.dispose);
      final coordinator = container.read(authSessionLifecycleProvider);

      fixture.auth.user = fixture.user('lifecycle-owner-a');
      await coordinator.initialize(fixture.auth.user);
      fixture.auth.user = null;
      await coordinator.synchronize(null);
      fixture.auth.user = fixture.user('lifecycle-owner-b');
      await coordinator.synchronize(fixture.auth.user);

      final boundary = container.read(authSessionBoundaryProvider);
      expect(
        boundary.blockingIssue,
        contains('owned by another ChronoSpark account'),
      );
      expect(boundary.isStorageReady, isFalse);
      expect(await fixture.readOwnerMarker(), 'user:lifecycle-owner-a');
      expect(
        fixture.events.where((String event) => event == 'resume_writes').length,
        1,
      );
    },
  );

  test(
    'real coordinator rejects direct A to B without a successful B handoff',
    () async {
      final fixture = AuthSessionLifecycleIntegrationFixture();
      final container = await fixture.createContainer();
      addTearDown(container.dispose);
      final coordinator = container.read(authSessionLifecycleProvider);

      fixture.auth.user = fixture.user('lifecycle-owner-a');
      await coordinator.initialize(fixture.auth.user);
      fixture.auth.user = fixture.user('lifecycle-owner-b');
      await coordinator.synchronize(fixture.auth.user);

      final boundary = container.read(authSessionBoundaryProvider);
      expect(
        boundary.blockingIssue,
        contains('owned by another ChronoSpark account'),
      );
      expect(boundary.isStorageReady, isFalse);
      expect(await fixture.readOwnerMarker(), 'user:lifecycle-owner-a');
    },
  );

  test('same-user refresh does not create another lifecycle handoff', () async {
    final fixture = AuthSessionLifecycleIntegrationFixture();
    final container = await fixture.createContainer();
    addTearDown(container.dispose);
    final coordinator = container.read(authSessionLifecycleProvider);

    fixture.auth.user = fixture.user('lifecycle-owner-a');
    await coordinator.initialize(fixture.auth.user);
    final int eventCount = fixture.events.length;
    await coordinator.synchronize(fixture.user('lifecycle-owner-a'));

    expect(
      container.read(authSessionBoundaryProvider).userId,
      'lifecycle-owner-a',
    );
    expect(container.read(authSessionBoundaryProvider).blockingIssue, isNull);
    expect(fixture.events, hasLength(eventCount));
  });

  test('restart retains A ownership, permits A, and rejects B', () async {
    final fixture = AuthSessionLifecycleIntegrationFixture();
    final first = await fixture.createContainer();
    final firstCoordinator = first.read(authSessionLifecycleProvider);
    fixture.auth.user = fixture.user('lifecycle-owner-a');
    await firstCoordinator.initialize(fixture.auth.user);
    fixture.auth.user = null;
    await firstCoordinator.synchronize(null);
    first.dispose();

    final restarted = await fixture.createContainer();
    addTearDown(restarted.dispose);
    final coordinator = restarted.read(authSessionLifecycleProvider);
    await coordinator.initialize(null);
    expect(restarted.read(authSessionBoundaryProvider).userId, isNull);
    expect(await fixture.readOwnerMarker(), 'user:lifecycle-owner-a');

    fixture.auth.user = fixture.user('lifecycle-owner-a');
    await coordinator.synchronize(fixture.auth.user);
    expect(
      restarted.read(authSessionBoundaryProvider).userId,
      'lifecycle-owner-a',
    );
    expect(restarted.read(authSessionBoundaryProvider).blockingIssue, isNull);
  });

  test('A to signed-out waits for the captured projection drain', () async {
    final StreamController<User?> users = StreamController<User?>.broadcast();
    addTearDown(users.close);
    final _BlockingProjection projection = _BlockingProjection();
    final fixture = AuthSessionLifecycleIntegrationFixture();
    final container = await fixture.createContainer(
      authUsers: users.stream,
      projectionCoordinator: projection,
    );
    addTearDown(container.dispose);
    container.read(taskOccurrenceProjectionCoordinatorProvider);
    users.add(fixture.user('lifecycle-owner-a'));
    await Future<void>.delayed(Duration.zero);
    final coordinator = container.read(authSessionLifecycleProvider);
    fixture.auth.user = fixture.user('lifecycle-owner-a');
    await coordinator.initialize(fixture.auth.user);
    projection.armed = true;
    users.add(null);
    await Future<void>.delayed(Duration.zero);
    fixture.auth.user = null;
    final transition = coordinator.synchronize(null);
    await projection.started.future;
    expect(container.read(authSessionBoundaryProvider).isTransitioning, isTrue);
    projection.release.complete();
    await transition;
    expect(
      container.read(authSessionBoundaryProvider).isTransitioning,
      isFalse,
    );
    expect(
      fixture.events,
      containsAllInOrder(<String>[
        'cancel_and_drain',
        'invalidate',
        'identity_handoff',
        'boundary_ready',
      ]),
    );
  });

  test(
    'live auth stream restores the same A lifecycle scope after sign-out',
    () async {
      final StreamController<User?> users = StreamController<User?>.broadcast();
      addTearDown(users.close);
      final fixture = AuthSessionLifecycleIntegrationFixture();
      final container = await fixture.createContainer(authUsers: users.stream);
      addTearDown(container.dispose);
      container.read(taskOccurrenceProjectionCoordinatorProvider);
      users.add(fixture.user('lifecycle-owner-a'));
      await Future<void>.delayed(Duration.zero);
      final coordinator = container.read(authSessionLifecycleProvider);
      fixture.auth.user = fixture.user('lifecycle-owner-a');
      await coordinator.initialize(fixture.auth.user);
      users.add(null);
      await Future<void>.delayed(Duration.zero);
      fixture.auth.user = null;
      await coordinator.synchronize(null);
      users.add(fixture.user('lifecycle-owner-a'));
      await Future<void>.delayed(Duration.zero);
      fixture.auth.user = fixture.user('lifecycle-owner-a');
      await coordinator.synchronize(fixture.auth.user);
      final boundary = container.read(authSessionBoundaryProvider);
      expect(boundary.userId, 'lifecycle-owner-a');
      expect(boundary.isStorageReady, isTrue);
      expect(boundary.blockingIssue, isNull);
    },
  );

  test(
    'live sign-out retains the captured A projection until lifecycle invalidation',
    () async {
      final StreamController<User?> users = StreamController<User?>.broadcast();
      addTearDown(users.close);
      final fixture = AuthSessionLifecycleIntegrationFixture();
      final container = await fixture.createContainer(authUsers: users.stream);
      addTearDown(container.dispose);
      container.read(taskOccurrenceProjectionCoordinatorProvider);
      final Completer<void> authenticated = Completer<void>();
      final ProviderSubscription<AsyncValue<User?>> authSubscription = container
          .listen<AsyncValue<User?>>(authUserProvider, (_, next) {
            if (next.asData?.value?.id == 'lifecycle-owner-a' &&
                !authenticated.isCompleted) {
              authenticated.complete();
            }
          });
      addTearDown(authSubscription.close);

      users.add(fixture.user('lifecycle-owner-a'));
      await authenticated.future;
      fixture.auth.user = fixture.user('lifecycle-owner-a');
      await container
          .read(authSessionLifecycleProvider)
          .initialize(fixture.auth.user);
      final TaskOccurrenceProjectionCoordinator captured = container.read(
        taskOccurrenceProjectionCoordinatorProvider,
      );
      expect(captured.scope.rawUserId, 'lifecycle-owner-a');

      users.add(null);
      await Future<void>.delayed(Duration.zero);

      final TaskOccurrenceProjectionCoordinator beforeLifecycleDrain = container
          .read(taskOccurrenceProjectionCoordinatorProvider);
      expect(identical(beforeLifecycleDrain, captured), isTrue);
      expect(beforeLifecycleDrain.scope.rawUserId, 'lifecycle-owner-a');

      fixture.auth.user = null;
      await container.read(authSessionLifecycleProvider).synchronize(null);

      final TaskOccurrenceProjectionCoordinator afterLifecycleInvalidation =
          container.read(taskOccurrenceProjectionCoordinatorProvider);
      expect(identical(afterLifecycleInvalidation, captured), isFalse);
      expect(afterLifecycleInvalidation.scope.isAuthenticated, isFalse);
    },
  );
}
