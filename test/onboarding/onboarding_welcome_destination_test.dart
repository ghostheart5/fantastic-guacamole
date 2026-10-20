import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/features/onboarding/ui/onboarding_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/services/intelligence_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final signedIn in [false, true]) {
    for (final language in ['en', 'es']) {
      testWidgets(
        'Welcome action matches $language signedIn=$signedIn destination',
        (tester) async {
          tester.view.physicalSize = const Size(1440, 2560);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          SharedPreferences.setMockInitialValues(<String, Object>{});
          final container = ProviderContainer(
            overrides: [
              intelligenceStateProvider.overrideWithValue(
                const IntelligenceService().fromRuntime(
                  hasMockSignIn: false,
                  hasAuthenticatedUser: signedIn,
                ),
              ),
              profileProvider.overrideWith(_TestProfileController.new),
            ],
          );
          final entryDestination = Env.isLocalMode
              ? 'LOCAL PROFILE DESTINATION'
              : 'SIGN IN DESTINATION';
          final router = GoRouter(
            initialLocation: '/welcome',
            routes: [
              GoRoute(
                path: '/welcome',
                builder: (_, _) =>
                    const OnboardingScreen(loginLocation: '/signin'),
              ),
              GoRoute(
                path: '/signin',
                builder: (_, _) => Scaffold(body: Text(entryDestination)),
              ),
            ],
          );
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            router.dispose();
            container.dispose();
          });
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp.router(
                routerConfig: router,
                locale: Locale(language),
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
          await tester.pump(const Duration(milliseconds: 400));
          final label = signedIn
              ? (language == 'es'
                    ? 'CONTINUAR CONFIGURACIÓN'
                    : 'CONTINUE TO SETUP')
              : Env.isLocalMode
              ? (language == 'es'
                    ? 'CONTINUAR AL PERFIL'
                    : 'CONTINUE TO PROFILE')
              : (language == 'es'
                    ? 'CONTINUAR AL ACCESO'
                    : 'CONTINUE TO LOGIN');
          final button = find.widgetWithText(FilledButton, label);
          expect(button.hitTestable(), findsOneWidget);
          await tester.tap(button);
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 500));
          if (signedIn) {
            expect(
              find.byKey(const Key('first-value-question')),
              findsOneWidget,
            );
            expect(find.text(entryDestination), findsNothing);
          } else {
            expect(find.text(entryDestination), findsOneWidget);
            expect(find.byKey(const Key('first-value-question')), findsNothing);
          }
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getBool(onboardingWelcomeCompleteStorageKey), isTrue);
          expect(prefs.getBool(onboardingCompleteStorageKey), isNot(true));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

class _TestProfileController extends ProfileController {
  @override
  ProfileState build() => ProfileState();
}
