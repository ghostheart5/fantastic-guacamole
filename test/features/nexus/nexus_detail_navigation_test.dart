import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mirrors the real router: every shell route shares one page key, so a pushed
// route stays on top while the page underneath changes in place.
const ValueKey<String> _pageKey = ValueKey<String>('test-shell');

// The detail screen runs a repeating pulse animation, so it never settles.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<GoRouter> pumpHost(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('nexus-detail-test'),
        ),
        unreadNotificationsProvider.overrideWithValue(0),
      ],
    );
    addTearDown(container.dispose);
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => NoTransitionPage<void>(
            key: _pageKey,
            child: Scaffold(
              body: Center(
                child: Builder(
                  builder: (inner) => TextButton(
                    onPressed: () => Navigator.of(inner).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const NexusScreen(showDetails: true),
                      ),
                    ),
                    child: const Text('open detail'),
                  ),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/trajectory',
          pageBuilder: (context, state) => const NoTransitionPage<void>(
            key: _pageKey,
            child: Scaffold(body: Text('trajectory destination')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: locale,
          supportedLocales: ChronoSparkLocalizations.supportedLocales,
          localizationsDelegates: const [
            ChronoSparkLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open detail'));
    await _settle(tester);
    expect(find.byType(NexusScreen), findsOneWidget);
    return router;
  }

  testWidgets('a button inside the detailed review lands on its destination', (
    tester,
  ) async {
    await pumpHost(tester);
    await tester.ensureVisible(find.text('MOMENTUM').first);
    await tester.tap(find.text('MOMENTUM').first);
    await _settle(tester);

    expect(find.byType(NexusScreen), findsNothing);
    expect(find.text('trajectory destination'), findsOneWidget);
    final BuildContext destination = tester.element(
      find.text('trajectory destination'),
    );
    expect(ModalRoute.of(destination)!.isCurrent, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the detailed review has a Back control that closes it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpHost(tester);
      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.bySemanticsLabel('Back'), findsWidgets);

      await tester.tap(find.byTooltip('Back'));
      await _settle(tester);

      expect(find.byType(NexusScreen), findsNothing);
      expect(find.text('open detail'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('the Back control is labelled in Spanish', (tester) async {
    await pumpHost(tester, locale: const Locale('es'));
    expect(find.byTooltip('Atrás'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
  });
}
