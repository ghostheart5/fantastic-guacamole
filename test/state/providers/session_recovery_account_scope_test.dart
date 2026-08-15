import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/session_recovery_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AccountStorageScope scope;
  late ProviderContainer container;

  setUp(() async {
    await SharedPrefsService.init();
    await SharedPrefsService.clear();
    scope = AccountStorageScope.authenticated('recovery-a');
    container = ProviderContainer(
      overrides: [accountStorageScopeProvider.overrideWith((Ref ref) => scope)],
    );
  });

  tearDown(() => container.dispose());

  test('provider isolates A and B recovery state and restores A', () async {
    final String aNamespace = scope.v2Namespace!;
    await container
        .read(sessionRecoveryProvider)
        .saveState(
          lastRoute: 'A_SECRET_ROUTE',
          activeTaskId: 'A_SECRET_TASK',
          draftTaskTitle: 'A_SECRET_DRAFT',
        );
    expect(
      SharedPrefsService.load('rec_last_route_v2.$aNamespace'),
      'A_SECRET_ROUTE',
    );
    expect(
      SharedPrefsService.load('rec_active_task_id_v2.$aNamespace'),
      'A_SECRET_TASK',
    );
    expect(
      SharedPrefsService.load('rec_draft_task_title_v2.$aNamespace'),
      'A_SECRET_DRAFT',
    );

    scope = AccountStorageScope.authenticated('recovery-b');
    container.invalidate(accountStorageScopeProvider);
    expect(await container.read(sessionRecoveryProvider).loadState(), isNull);

    await container
        .read(sessionRecoveryProvider)
        .saveState(
          lastRoute: 'B_SECRET_ROUTE',
          activeTaskId: 'B_SECRET_TASK',
          draftTaskTitle: 'B_SECRET_DRAFT',
        );
    final String bNamespace = scope.v2Namespace!;
    expect(
      SharedPrefsService.load('rec_last_route_v2.$bNamespace'),
      'B_SECRET_ROUTE',
    );

    scope = AccountStorageScope.authenticated('recovery-a');
    container.invalidate(accountStorageScopeProvider);
    final state = await container.read(sessionRecoveryProvider).loadState();
    expect(state?.lastRoute, 'A_SECRET_ROUTE');
    expect(state?.activeTaskId, 'A_SECRET_TASK');
    expect(state?.draftTaskTitle, 'A_SECRET_DRAFT');
  });

  test(
    'signed-out recovery is unavailable and legacy signed-out state is inert',
    () async {
      await container
          .read(sessionRecoveryProvider)
          .saveState(lastRoute: 'A_SECRET_ROUTE');
      await SharedPrefsService.save(
        'rec_last_route.signed_out',
        'LEGACY_ROUTE',
      );
      final Map<String, String> before = SharedPrefsService.getAll();

      scope = const AccountStorageScope.signedOut();
      container.invalidate(accountStorageScopeProvider);
      final recovery = container.read(sessionRecoveryProvider);
      expect(recovery.isAvailable, isFalse);
      expect(await recovery.loadState(), isNull);
      await recovery.saveState(lastRoute: 'SHOULD_NOT_PERSIST');

      expect(SharedPrefsService.getAll(), before);

      scope = AccountStorageScope.authenticated('recovery-b');
      container.invalidate(accountStorageScopeProvider);
      expect(await container.read(sessionRecoveryProvider).loadState(), isNull);
      expect(
        SharedPrefsService.load('rec_last_route.signed_out'),
        'LEGACY_ROUTE',
      );
    },
  );

  test(
    'clearAll affects only the current authenticated V2 namespace',
    () async {
      await container
          .read(sessionRecoveryProvider)
          .saveState(lastRoute: 'A_ROUTE');
      scope = AccountStorageScope.authenticated('recovery-b');
      container.invalidate(accountStorageScopeProvider);
      await container
          .read(sessionRecoveryProvider)
          .saveState(lastRoute: 'B_ROUTE');

      scope = AccountStorageScope.authenticated('recovery-a');
      container.invalidate(accountStorageScopeProvider);
      await container.read(sessionRecoveryProvider).clearAll();
      expect(await container.read(sessionRecoveryProvider).loadState(), isNull);

      scope = AccountStorageScope.authenticated('recovery-b');
      container.invalidate(accountStorageScopeProvider);
      expect(
        (await container.read(sessionRecoveryProvider).loadState())?.lastRoute,
        'B_ROUTE',
      );
    },
  );

  test(
    'fresh provider containers restore only their authenticated V2 scope',
    () async {
      await container
          .read(sessionRecoveryProvider)
          .saveState(lastRoute: 'A_RESTART_ROUTE');
      container.dispose();
      container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWith((Ref ref) => scope),
        ],
      );
      expect(
        (await container.read(sessionRecoveryProvider).loadState())?.lastRoute,
        'A_RESTART_ROUTE',
      );
    },
  );
}
