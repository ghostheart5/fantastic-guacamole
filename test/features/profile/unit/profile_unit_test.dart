import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/features/auth/domain/models/chronospark_identity.dart';
import 'package:fantastic_guacamole/features/profile/ui/profile_screen.dart';
import 'package:fantastic_guacamole/features/profile/ui/widgets/profile_header.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/models/profile_model.dart';
import 'package:fantastic_guacamole/state/models/profile_view_state.dart';
import 'package:fantastic_guacamole/state/providers/identity_account_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('ProfileHeader', () {
    testWidgets('renders name and level chip text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileHeader(
              name: 'Keegan',
              level: 7,
              onBack: () {},
              onOpenSettings: () {},
            ),
          ),
        ),
      );

      expect(find.text('Keegan'), findsOneWidget);
      expect(find.text('Level 7'), findsOneWidget);
    });

    testWidgets('fires back and settings callbacks', (WidgetTester tester) async {
      int backTaps = 0;
      int settingsTaps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileHeader(
              name: 'Operator',
              level: 1,
              onBack: () => backTaps++,
              onOpenSettings: () => settingsTaps++,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(backTaps, 1);
      expect(settingsTaps, 1);
    });
  });

  group('ProfileScreen', () {
    testWidgets('surfaces identity, progression, and danger-zone blocks', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          profileViewStateProvider.overrideWithValue(
            const ProfileViewState(
              profile: ProfileModel(
                name: 'Operator Nova',
                level: 7,
                xp: 135,
                streak: 9,
                longestStreak: 14,
                soundEnabled: true,
              ),
              loading: false,
            ),
          ),
          identityAccountProvider.overrideWith(
            _IdentityAccountControllerFake.new,
          ),
          mockAuthSessionProvider.overrideWith(_MockAuthSessionTrue.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Identity'), findsOneWidget);
      expect(find.text('Progress status'), findsOneWidget);
      expect(find.text('Danger zone'), findsOneWidget);
      expect(find.text('Operator Nova'), findsWidgets);
      expect(find.textContaining('Tier: FREE'), findsOneWidget);
      expect(find.textContaining('Provider: EMAIL'), findsOneWidget);
      expect(find.textContaining('Sync: SYNCED'), findsOneWidget);
      expect(find.textContaining('XP 135'), findsOneWidget);
      expect(find.text('Log out'), findsOneWidget);
      expect(find.text('Delete account'), findsNothing);

      await tester.tap(find.text('Open'));
      await tester.pump();

      expect(container.read(appFlowProvider), AppView.progression);
    });

    testWidgets('opens hosted delete-account page for signed-in sessions', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          profileViewStateProvider.overrideWithValue(
            const ProfileViewState(
              profile: ProfileModel(
                name: 'Operator Nova',
                level: 7,
                xp: 135,
                streak: 9,
                longestStreak: 14,
                soundEnabled: true,
              ),
              loading: false,
            ),
          ),
          identityAccountProvider.overrideWith(
            _IdentityAccountControllerFake.new,
          ),
          mockAuthSessionProvider.overrideWith(_MockAuthSessionFalse.new),
        ],
      );
      addTearDown(container.dispose);

      final GoRouter router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) {
              return UncontrolledProviderScope(
                container: container,
                child: const ProfileScreen(),
              );
            },
          ),
          GoRoute(
            path: RoutePaths.deleteAccount,
            builder: (BuildContext context, GoRouterState state) {
              return const Scaffold(body: Text('Delete Account Page'));
            },
          ),
          GoRoute(
            path: RoutePaths.login,
            builder: (BuildContext context, GoRouterState state) {
              return const Scaffold(body: Text('Login Page'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Delete account'), findsOneWidget);

      await tester.tap(find.text('Delete account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Delete Account Page'), findsOneWidget);
    });
  });
}

class _IdentityAccountControllerFake extends IdentityAccountController {
  @override
  ChronoSparkIdentity? build() {
    return ChronoSparkIdentity(
      id: 'identity-1',
      email: 'operator@chronospark.app',
      displayName: 'Operator Nova',
      createdAt: DateTime(2026, 1, 1),
      lastActiveAt: DateTime(2026, 8, 2),
      lifeOsMission: 'Protect signal clarity and finish decisive work.',
      identityStage: 'Ascendant',
      accountTier: ChronoSparkAccountTier.free,
      authProvider: ChronoSparkAuthProvider.email,
      syncStatus: ChronoSparkIdentitySyncStatus.synced,
      emailVerified: true,
    );
  }
}

class _MockAuthSessionTrue extends MockAuthSessionNotifier {
  @override
  bool build() => true;
}

class _MockAuthSessionFalse extends MockAuthSessionNotifier {
  @override
  bool build() => false;
}

