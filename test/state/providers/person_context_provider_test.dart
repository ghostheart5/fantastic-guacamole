import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
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
      personContextForSurfaceProvider(PersonContextSurface.smartPlanner),
    );
    final PersonContextView? nexus = container.read(
      personContextForSurfaceProvider(PersonContextSurface.nexus),
    );
    final PersonContextView? creator = container.read(
      personContextForSurfaceProvider(PersonContextSurface.creator),
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
        personContextForSurfaceProvider(PersonContextSurface.smartPlanner),
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
        personContextForSurfaceProvider(PersonContextSurface.smartPlanner),
      ),
      isNull,
    );
  });
}
