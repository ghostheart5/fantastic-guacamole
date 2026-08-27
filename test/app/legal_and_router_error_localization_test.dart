import 'package:fantastic_guacamole/app/router/app_router.dart';
import 'package:fantastic_guacamole/app/router/info_pages.dart';
import 'package:fantastic_guacamole/app/router/route_guards.dart' as guards;
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/ui/widgets/web_page_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _authenticatedStateProvider = NotifierProvider<_TestBoolNotifier, bool>(
  _TestBoolNotifier.new,
);
final _welcomeCompleteStateProvider = NotifierProvider<_TestBoolNotifier, bool>(
  _TestBoolNotifier.new,
);
final _onboardingCompleteStateProvider =
    NotifierProvider<_TestBoolNotifier, bool>(_TestBoolNotifier.new);

class _TestBoolNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

void _setGuardState(
  ProviderContainer container, {
  required bool authenticated,
  required bool welcomeComplete,
  required bool onboardingComplete,
}) {
  container.read(_authenticatedStateProvider.notifier).set(authenticated);
  container.read(_welcomeCompleteStateProvider.notifier).set(welcomeComplete);
  container
      .read(_onboardingCompleteStateProvider.notifier)
      .set(onboardingComplete);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('legal and support route localization', () {
    for (final _LocalizedRouteExpectation expectation
        in _localizedRouteExpectations) {
      testWidgets(
        '${expectation.path} renders localized ${expectation.locale.languageCode} copy',
        (WidgetTester tester) async {
          final _RouterHarness harness = await _pumpAppRouter(
            tester,
            initialLocation: expectation.path,
            locale: expectation.locale,
            authenticated: false,
            welcomeComplete: false,
            onboardingComplete: false,
          );

          await tester.pump();
          await tester.pump();

          expect(
            harness.router.routeInformationProvider.value.uri.path,
            expectation.path,
          );
          expect(find.byType(WebPageView), findsOneWidget);
          expect(find.text(expectation.title), findsOneWidget);
          expect(find.text(expectation.body), findsOneWidget);
          expect(find.text(expectation.callToAction), findsOneWidget);

          await tester.pumpWidget(const SizedBox.shrink());
          harness.dispose();
        },
      );
    }
  });

  group('router error localization', () {
    for (final _RouterErrorExpectation expectation
        in _routerErrorExpectations) {
      testWidgets(
        'unknown routes render localized ${expectation.locale.languageCode} error copy',
        (WidgetTester tester) async {
          final _RouterHarness harness = await _pumpAppRouter(
            tester,
            initialLocation:
                '/not-a-chronospark-route?token=sk-test-secret&message=raw',
            locale: expectation.locale,
            authenticated: true,
            welcomeComplete: true,
            onboardingComplete: true,
          );

          await tester.pump();
          await tester.pump();

          expect(find.byType(RouteErrorPage), findsOneWidget);
          expect(find.text(expectation.title), findsWidgets);
          expect(find.text(expectation.body), findsOneWidget);
          expect(find.text(expectation.recoveryLabel), findsOneWidget);
          expect(find.textContaining('GoException'), findsNothing);
          expect(find.textContaining('no routes'), findsNothing);
          expect(find.textContaining('not-a-chronospark-route'), findsNothing);
          expect(find.textContaining('sk-test-secret'), findsNothing);
          expect(find.textContaining('raw'), findsNothing);

          await tester.pumpWidget(const SizedBox.shrink());
          harness.dispose();
        },
      );
    }

    testWidgets(
      'unknown-route recovery action navigates to the policy target',
      (WidgetTester tester) async {
        final GoRouter router = GoRouter(
          initialLocation: '/missing',
          errorBuilder: (BuildContext context, GoRouterState state) =>
              RouteErrorPage(
                location: state.uri.toString(),
                error: state.error,
                isAuthenticated: false,
                welcomeComplete: true,
                onboardingComplete: false,
              ),
          routes: <RouteBase>[
            GoRoute(
              path: RoutePaths.login,
              builder: (BuildContext context, GoRouterState state) =>
                  const Text('Login recovery destination'),
            ),
          ],
        );

        await tester.pumpWidget(
          _LocalizedRouterApp(router: router, locale: const Locale('en')),
        );
        await tester.pump();

        expect(find.byType(RouteErrorPage), findsOneWidget);
        await tester.tap(find.text('Return to Login'));
        await tester.pumpAndSettle();

        expect(
          router.routeInformationProvider.value.uri.path,
          RoutePaths.login,
        );
        expect(find.text('Login recovery destination'), findsOneWidget);
        router.dispose();
      },
    );
  });
}

Future<_RouterHarness> _pumpAppRouter(
  WidgetTester tester, {
  required String initialLocation,
  required Locale locale,
  required bool authenticated,
  required bool welcomeComplete,
  required bool onboardingComplete,
}) async {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      guards.authenticatedGuardProvider.overrideWith(
        (Ref ref) => ref.watch(_authenticatedStateProvider),
      ),
      guards.onboardingWelcomeCompleteGuardProvider.overrideWith(
        (Ref ref) => ref.watch(_welcomeCompleteStateProvider),
      ),
      guards.onboardingCompleteGuardProvider.overrideWith(
        (Ref ref) => ref.watch(_onboardingCompleteStateProvider),
      ),
    ],
  );
  _setGuardState(
    container,
    authenticated: authenticated,
    welcomeComplete: welcomeComplete,
    onboardingComplete: onboardingComplete,
  );

  final GoRouter router = container.read(appRouterProvider);
  router.go(initialLocation);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: _LocalizedRouterApp(router: router, locale: locale),
    ),
  );

  return _RouterHarness(container: container, router: router);
}

class _LocalizedRouterApp extends StatelessWidget {
  const _LocalizedRouterApp({required this.router, required this.locale});

  final GoRouter router;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      locale: locale,
      supportedLocales: ChronoSparkLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        ChronoSparkLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}

class _RouterHarness {
  _RouterHarness({required this.container, required this.router});

  final ProviderContainer container;
  final GoRouter router;

  void dispose() {
    container.dispose();
  }
}

class _LocalizedRouteExpectation {
  const _LocalizedRouteExpectation({
    required this.path,
    required this.locale,
    required this.title,
    required this.body,
    required this.callToAction,
  });

  final String path;
  final Locale locale;
  final String title;
  final String body;
  final String callToAction;
}

class _RouterErrorExpectation {
  const _RouterErrorExpectation({
    required this.locale,
    required this.title,
    required this.body,
    required this.recoveryLabel,
  });

  final Locale locale;
  final String title;
  final String body;
  final String recoveryLabel;
}

const List<_LocalizedRouteExpectation>
_localizedRouteExpectations = <_LocalizedRouteExpectation>[
  _LocalizedRouteExpectation(
    path: RoutePaths.privacy,
    locale: Locale('en'),
    title: 'Privacy Policy',
    body:
        'ChronoSpark publishes its authoritative privacy policy at the public HTTPS URL below. Use the hosted policy for current data handling, retention, and support terms.',
    callToAction: 'Open Hosted Privacy Policy',
  ),
  _LocalizedRouteExpectation(
    path: RoutePaths.privacy,
    locale: Locale('es'),
    title: 'Política de privacidad',
    body:
        'ChronoSpark publica su política de privacidad autorizada en la URL HTTPS pública de abajo. Usa la política alojada para consultar el manejo de datos, la retención y los términos de soporte actuales.',
    callToAction: 'Abrir política de privacidad alojada',
  ),
  _LocalizedRouteExpectation(
    path: RoutePaths.terms,
    locale: Locale('en'),
    title: 'Terms of Service',
    body:
        'ChronoSpark maintains its current Terms of Service on the public HTTPS page below so release builds and store listings reference the same source of truth.',
    callToAction: 'Open Hosted Terms',
  ),
  _LocalizedRouteExpectation(
    path: RoutePaths.terms,
    locale: Locale('es'),
    title: 'Términos de servicio',
    body:
        'ChronoSpark mantiene sus Términos de servicio actuales en la página HTTPS pública de abajo para que las versiones de lanzamiento y las fichas de tienda apunten a la misma fuente de verdad.',
    callToAction: 'Abrir términos alojados',
  ),
  _LocalizedRouteExpectation(
    path: RoutePaths.deleteAccount,
    locale: Locale('en'),
    title: 'Delete Account',
    body:
        'ChronoSpark publishes account deletion steps at the public HTTPS URL below. Use the hosted page to submit a deletion request and review deletion and retention details.',
    callToAction: 'Open Hosted Delete Account Page',
  ),
  _LocalizedRouteExpectation(
    path: RoutePaths.deleteAccount,
    locale: Locale('es'),
    title: 'Eliminar cuenta',
    body:
        'ChronoSpark publica los pasos para eliminar una cuenta en la URL HTTPS pública de abajo. Usa la página alojada para enviar una solicitud y revisar los detalles de eliminación y retención.',
    callToAction: 'Abrir página alojada para eliminar cuenta',
  ),
  _LocalizedRouteExpectation(
    path: RoutePaths.support,
    locale: Locale('en'),
    title: 'Support',
    body:
        'ChronoSpark publishes release-facing support and account assistance at the public HTTPS URL below so store reviewers and users can reach the current support process from every build.',
    callToAction: 'Open Hosted Support Page',
  ),
  _LocalizedRouteExpectation(
    path: RoutePaths.support,
    locale: Locale('es'),
    title: 'Soporte',
    body:
        'ChronoSpark publica soporte y ayuda de cuenta para lanzamientos en la URL HTTPS pública de abajo para que revisores de tienda y usuarios puedan llegar al proceso de soporte actual desde cada versión.',
    callToAction: 'Abrir página de soporte alojada',
  ),
];

const List<_RouterErrorExpectation>
_routerErrorExpectations = <_RouterErrorExpectation>[
  _RouterErrorExpectation(
    locale: Locale('en'),
    title: "We couldn't open that link",
    body:
        'The link does not match an available ChronoSpark screen. We recorded a safe diagnostic event without exposing technical details.',
    recoveryLabel: 'Return to Nexus',
  ),
  _RouterErrorExpectation(
    locale: Locale('es'),
    title: 'No pudimos abrir ese enlace',
    body:
        'El enlace no coincide con una pantalla disponible de ChronoSpark. Registramos un diagnóstico seguro sin mostrar detalles técnicos.',
    recoveryLabel: 'Volver a Nexus',
  ),
];
