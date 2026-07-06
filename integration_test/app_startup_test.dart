import 'package:fantastic_guacamole/app/app_root.dart';
import 'package:fantastic_guacamole/app/navigation_shell.dart';
import 'package:fantastic_guacamole/domain/entities/app_theme_entity.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/onboarding/onboarding_screen.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/theme_provider.dart';
import 'package:fantastic_guacamole/state/state/intelligence_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('startup hydration boots app root and completes state bootstrap', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        onboardingCompleteProvider.overrideWith(_OnboardingIncompleteNotifier.new),
        intelligenceStateProvider.overrideWithValue(_authenticatedIntelligence),
        currentThemeProvider.overrideWith(_StaticThemeController.new),
        siStateProvider.overrideWith(_FixedSiStateController.new),
        learningProvider.overrideWith(_FixedLearningController.new),
      ],
    );
    addTearDown(container.dispose);

    await container.read(stateBootstrapProvider.future);
    expect(container.read(latestSiSnapshotProvider), isNotNull);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const AppRoot()),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(
      find.byType(OnboardingScreen),
      findsOneWidget,
      reason: 'With onboarding incomplete, app should route to onboarding surface.',
    );
    expect(find.byType(NavigationShell), findsNothing);
  });
}

const IntelligenceState _authenticatedIntelligence = IntelligenceState(
  environment: EnvironmentState(
    appName: 'ChronoSpark',
    appFlavor: 'test',
    isProduction: false,
    isSupabaseConfigured: false,
  ),
  flags: FeatureFlagsState(
    verboseLogs: false,
    analyticsEnabled: false,
    mockMode: false,
    mockLoginEnabled: true,
    paywallDisabled: false,
    testerFullAccess: false,
  ),
  auth: AuthStateSnapshot(hasMockSession: true, hasAuthenticatedUser: true),
  mockLogin: MockLoginConfigState(email: '', password: ''),
);

class _OnboardingIncompleteNotifier extends OnboardingCompleteNotifier {
  @override
  bool build() => false;
}

class _StaticThemeController extends CurrentThemeController {
  @override
  Future<AppThemeEntity> build() async => AppThemeEntity.defaultTheme();
}

class _FixedSiStateController extends SIStateController {
  @override
  SIState build() => const SIState(energy: 0.75, fatigue: 0.2, completedToday: 1);
}

class _FixedLearningController extends LearningController {
  @override
  LearningState build() => const LearningState();
}
