import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/app/app_root.dart';
import 'package:fantastic_guacamole/app/router/app_router.dart';
import 'package:fantastic_guacamole/app/router/route_guards.dart' as guards;
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/storage/account_scoped_shared_prefs_store.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:fantastic_guacamole/features/settings/ui/settings_screen.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_coordinator_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/models/personalization_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_task_repository.dart';

void main() {
  testWidgets(
    'AppRoot fences an actual A B A transition before profile hydration',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await SharedPrefsService.init();
      await SharedPrefsService.clear();
      final backend = _BlockingAccountMarkerBackend();
      final store = SecureStore(backend: backend);
      await store.writeString('auth_boundary_account_marker_v1', 'account-a');
      for (final account in ['account-a', 'account-b']) {
        await store
            .forAccount(AccountStorageScope.authenticated(account))
            .writeString(
              'profile_state_v2',
              jsonEncode({
                'name': 'Private $account',
                'xp': account == 'account-a' ? 75 : 25,
              }),
            );
        await AccountScopedSharedPrefsStore(
          delegate: const SharedPrefsStoreAdapter(),
          scope: AccountStorageScope.authenticated(account),
        ).save(
          personalizationProfileStorageKey,
          jsonEncode(PersonalizationProfile(goalCategory: account).toJson()),
        );
      }
      final auth = StreamController<User?>.broadcast();
      final container = ProviderContainer(
        overrides: [
          authUserProvider.overrideWith((ref) => auth.stream),
          secureStoreProvider.overrideWithValue(store),
          // This widget fixture uses in-memory account data. Physical goal
          // reopening is covered by the canonical repository integration test.
          accountGoalStoragePreparationProvider.overrideWithValue(
            (scope, ownership) async {},
          ),
          sensitivePrefsStoreProvider.overrideWithValue(
            const SharedPrefsStoreAdapter(),
          ),
          domainTaskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
          guards.onboardingWelcomeCompleteGuardProvider.overrideWithValue(true),
          guards.onboardingCompleteGuardProvider.overrideWithValue(true),
        ],
      );
      bool containerDisposed = false;
      addTearDown(() async {
        backend.releaseMarkerRead();
        if (!containerDisposed) container.dispose();
        await auth.close();
      });
      final initialization = container
          .read(authSessionBoundaryCoordinatorProvider)
          .initialize();
      auth.add(const User(id: 'account-a', emailVerified: true));
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const AppRoot()),
      );
      await tester.pump();
      await initialization;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        container.read(accountStorageScopeProvider).rawUserId,
        'account-a',
      );
      expect(find.byType(NexusScreen), findsOneWidget);
      expect(find.textContaining('PRIVATE ACCOUNT-A'), findsOneWidget);
      expect(
        container.read(personalizationProfileProvider).goalCategory,
        'account-a',
      );

      for (final account in ['account-b', 'account-a']) {
        final previous = container.read(accountStorageScopeProvider).rawUserId!;
        backend.blockMarkerRead();
        auth.add(User(id: account, emailVerified: true));
        await tester.pump();
        expect(container.read(accountStorageScopeProvider).isWritable, isFalse);
        expect(
          container.read(authSessionBoundaryProvider).isTransitioning,
          isTrue,
        );
        expect(find.text('Securing account data'), findsOneWidget);
        expect(find.byType(NexusScreen), findsNothing);
        expect(
          find.textContaining('PRIVATE ${previous.toUpperCase()}'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        expect(container.read(goalsProvider), isEmpty);
        expect(container.read(timelineProvider), isEmpty);
        expect(container.read(profileProvider).xp, 0);
        expect(container.read(personalizationProfileProvider).goalCategory, '');

        backend.releaseMarkerRead();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final router = container.read(appRouterProvider);
        router.go(RoutePaths.nexus);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(container.read(accountStorageScopeProvider).rawUserId, account);
        expect(container.read(profileProvider).name, 'Private $account');
        expect(
          container.read(personalizationProfileProvider).goalCategory,
          account,
        );
        expect(
          container.read(profileProvider).xp,
          account == 'account-a' ? 75 : 25,
        );
        expect(
          find.textContaining('PRIVATE ${account.toUpperCase()}'),
          findsOneWidget,
        );
        expect(
          find.textContaining('PRIVATE ${previous.toUpperCase()}'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);

        router.go(RoutePaths.settings);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      containerDisposed = true;
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _BlockingAccountMarkerBackend extends InMemorySecureStoreBackend {
  Completer<void>? _markerRead;

  void blockMarkerRead() => _markerRead = Completer<void>();

  void releaseMarkerRead() {
    _markerRead?.complete();
    _markerRead = null;
  }

  @override
  Future<String?> read({required String key}) async {
    if (key == 'auth_boundary_account_marker_v1') await _markerRead?.future;
    return super.read(key: key);
  }
}
