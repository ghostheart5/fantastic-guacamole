import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/person_context_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/person_context_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 30, 12);
  final AccountStorageScope accountA = AccountStorageScope.authenticated(
    'account-a',
  );

  PersonContextSpine spineFor(AccountStorageScope scope) => PersonContextSpine(
    accountScopeId: scope.v2Namespace!,
    updatedAt: now,
    signals: <PersonContextSignal>[
      PersonContextSignal(
        id: 'priority',
        kind: PersonContextKind.currentPriority,
        value: 'Protect family time tonight',
        source: PersonContextSource.userAuthored,
        consent: PersonContextConsent.granted,
        consentedAt: now,
        purpose: PersonContextPurpose.decisionSupport,
        surfaceScopes: const <PersonContextSurface>{
          PersonContextSurface.smartPlanner,
          PersonContextSurface.nexus,
        },
        recordedAt: now,
        freshUntil: now.add(const Duration(days: 7)),
        expiresAt: now.add(const Duration(days: 30)),
        exportBehavior: PersonContextExportBehavior.include,
        deletionBehavior: PersonContextDeletionBehavior.userRemovable,
      ),
    ],
  );

  PersonContextAccessRequest access(PersonContextSurface surface) =>
      PersonContextAccessRequest(
        surface: surface,
        purposes: const <PersonContextPurpose>{
          PersonContextPurpose.decisionSupport,
        },
      );

  test('every surface projects from the same loaded spine', () async {
    final PersonContextSpine spine = spineFor(accountA);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(accountA),
        personContextClockProvider.overrideWithValue(() => now),
        personContextSpineProvider.overrideWith((Ref ref) async => spine),
      ],
    );
    addTearDown(container.dispose);
    await container.read(personContextSpineProvider.future);

    final PersonContextView? planner = container.read(
      personContextForSurfaceProvider(
        access(PersonContextSurface.smartPlanner),
      ),
    );
    final PersonContextView? nexus = container.read(
      personContextForSurfaceProvider(access(PersonContextSurface.nexus)),
    );
    final PersonContextView? creator = container.read(
      personContextForSurfaceProvider(access(PersonContextSurface.creator)),
    );

    expect(planner?.signals.single.id, 'priority');
    expect(nexus?.signals.single.id, 'priority');
    expect(creator?.signals, isEmpty);
    expect(identical(planner?.signals.single, nexus?.signals.single), isTrue);
  });

  test('a stale spine from another account is never exposed', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('account-b'),
        ),
        personContextClockProvider.overrideWithValue(() => now),
        personContextSpineProvider.overrideWith(
          (Ref ref) async => spineFor(accountA),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(personContextSpineProvider.future);

    expect(
      container.read(
        personContextForSurfaceProvider(
          access(PersonContextSurface.smartPlanner),
        ),
      ),
      isNull,
    );
  });

  test('unsafe account scope fails closed', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          const AccountStorageScope.unsafe(),
        ),
        personContextClockProvider.overrideWithValue(() => now),
        personContextSpineProvider.overrideWith(
          (Ref ref) async => spineFor(accountA),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(personContextSpineProvider.future);

    expect(
      container.read(
        personContextForSurfaceProvider(
          access(PersonContextSurface.smartPlanner),
        ),
      ),
      isNull,
    );
  });

  test('surface projection invalidates at its freshness boundary', () async {
    DateTime current = now;
    late void Function() fireTransition;
    final PersonContextSpine spine = spineFor(accountA);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(accountA),
        personContextClockProvider.overrideWithValue(() => current),
        personContextTimerFactoryProvider.overrideWithValue((
          Duration duration,
          void Function() callback,
        ) {
          fireTransition = callback;
          return Timer(const Duration(days: 1), () {});
        }),
        personContextSpineProvider.overrideWith((Ref ref) async => spine),
      ],
    );
    addTearDown(container.dispose);
    await container.read(personContextSpineProvider.future);
    final provider = personContextForSurfaceProvider(
      access(PersonContextSurface.smartPlanner),
    );
    final subscription = container.listen<PersonContextView?>(
      provider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect(container.read(provider)?.signals, hasLength(1));

    current = now.add(const Duration(days: 8));
    fireTransition();
    await container.pump();

    expect(container.read(provider)?.signals, isEmpty);
  });

  test('expiry boundary reloads the spine and purges stored data', () async {
    DateTime current = now;
    late void Function() fireTransition;
    final _MemoryStore store = _MemoryStore();
    final PersonContextRepository repository = PersonContextRepository(
      store,
      accountA,
      clock: () => current,
    );
    final DateTime expiresAt = now.add(const Duration(hours: 1));
    await repository.upsert(
      PersonContextSignal(
        id: 'expiring-capacity',
        kind: PersonContextKind.presentCapacity,
        value: 'Low capacity this afternoon',
        source: PersonContextSource.userAuthored,
        consent: PersonContextConsent.granted,
        consentedAt: now,
        purpose: PersonContextPurpose.decisionSupport,
        surfaceScopes: const <PersonContextSurface>{
          PersonContextSurface.smartPlanner,
        },
        recordedAt: now,
        freshUntil: expiresAt,
        expiresAt: expiresAt,
        exportBehavior: PersonContextExportBehavior.include,
        deletionBehavior: PersonContextDeletionBehavior.expiresAutomatically,
      ),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(accountA),
        personContextClockProvider.overrideWithValue(() => current),
        personContextRepositoryProvider.overrideWithValue(repository),
        personContextTimerFactoryProvider.overrideWithValue((
          Duration duration,
          void Function() callback,
        ) {
          fireTransition = callback;
          return Timer(const Duration(days: 1), () {});
        }),
      ],
    );
    addTearDown(container.dispose);
    await container.read(personContextSpineProvider.future);
    final provider = personContextForSurfaceProvider(
      access(PersonContextSurface.smartPlanner),
    );
    final subscription = container.listen<PersonContextView?>(
      provider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect(container.read(provider)?.signals, hasLength(1));

    current = expiresAt.add(const Duration(seconds: 1));
    fireTransition();
    await container.pump();
    final PersonContextSpine? reloaded = await container.read(
      personContextSpineProvider.future,
    );
    await container.pump();

    expect(reloaded?.signals, isEmpty);
    final Map<String, dynamic> stored =
        jsonDecode(store.load(repository.storageKey!)!) as Map<String, dynamic>;
    expect(stored['signals'], isEmpty);
    expect(container.read(provider)?.signals, isEmpty);
  });
}

final class _MemoryStore implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => values[key];

  @override
  Future<void> save(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> clear() async {
    values.clear();
  }
}
