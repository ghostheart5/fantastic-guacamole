import 'package:fantastic_guacamole/state/providers/auth_session_lifecycle_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_session_lifecycle_integration_fixture.dart';

void main() {
  test('real coordinator signs the owning account out in lifecycle order', () async {
    final fixture = AuthSessionLifecycleIntegrationFixture();
    final container = await fixture.createContainer();
    addTearDown(container.dispose);

    fixture.auth.user = fixture.user('lifecycle-owner-a');
    final coordinator = container.read(authSessionLifecycleProvider);
    await coordinator.initialize(fixture.auth.user);
    expect(container.read(authSessionBoundaryProvider).userId, 'lifecycle-owner-a');
    expect(container.read(authSessionBoundaryProvider).isTransitioning, isFalse);
    expect(container.read(authSessionBoundaryProvider).blockingIssue, isNull);

    fixture.auth.user = null;
    await coordinator.synchronize(null);

    expect(container.read(authSessionBoundaryProvider).userId, isNull);
    expect(container.read(authSessionBoundaryProvider).isTransitioning, isFalse);
    expect(container.read(authSessionBoundaryProvider).blockingIssue, isNull);
    expect(fixture.notificationPlatformCalls, contains('cancelAll'));
    expect(fixture.events, containsAllInOrder(<String>[
      'suspend_writes',
      'cancel_and_drain',
      'invalidate',
      'identity_handoff',
      'boundary_ready',
    ]));
  });

  test('real coordinator supports owning A sign-out then same-owner reauthentication', () async {
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
  });

  test('real coordinator rejects B after A has signed out and retained ownership', () async {
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
    expect(boundary.blockingIssue, contains('owned by another ChronoSpark account'));
    expect(boundary.isStorageReady, isFalse);
    expect(await fixture.readOwnerMarker(), 'user:lifecycle-owner-a');
    expect(fixture.events.where((String event) => event == 'resume_writes').length, 1);
  });

  test('real coordinator rejects direct A to B without a successful B handoff', () async {
    final fixture = AuthSessionLifecycleIntegrationFixture();
    final container = await fixture.createContainer();
    addTearDown(container.dispose);
    final coordinator = container.read(authSessionLifecycleProvider);

    fixture.auth.user = fixture.user('lifecycle-owner-a');
    await coordinator.initialize(fixture.auth.user);
    fixture.auth.user = fixture.user('lifecycle-owner-b');
    await coordinator.synchronize(fixture.auth.user);

    final boundary = container.read(authSessionBoundaryProvider);
    expect(boundary.blockingIssue, contains('owned by another ChronoSpark account'));
    expect(boundary.isStorageReady, isFalse);
    expect(await fixture.readOwnerMarker(), 'user:lifecycle-owner-a');
  });

  test('same-user refresh does not create another lifecycle handoff', () async {
    final fixture = AuthSessionLifecycleIntegrationFixture();
    final container = await fixture.createContainer();
    addTearDown(container.dispose);
    final coordinator = container.read(authSessionLifecycleProvider);

    fixture.auth.user = fixture.user('lifecycle-owner-a');
    await coordinator.initialize(fixture.auth.user);
    final int eventCount = fixture.events.length;
    await coordinator.synchronize(fixture.user('lifecycle-owner-a'));

    expect(container.read(authSessionBoundaryProvider).userId, 'lifecycle-owner-a');
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
    expect(restarted.read(authSessionBoundaryProvider).userId, 'lifecycle-owner-a');
    expect(restarted.read(authSessionBoundaryProvider).blockingIssue, isNull);
  });
}
