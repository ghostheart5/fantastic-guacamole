import 'package:fantastic_guacamole/data/services/remote_config_service.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/feature_flags_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/state/intelligence_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'non-production tester access enables assistant release surfaces',
    () async {
      final ProviderContainer container = _container(isProduction: false);
      addTearDown(container.dispose);

      final AssistantReleaseConfig config = await container.read(
        assistantReleaseConfigProvider.future,
      );

      expect(config.stage, AssistantReleaseStage.general);
    },
  );

  test('tester access cannot bypass production release stage', () async {
    final ProviderContainer container = _container(isProduction: true);
    addTearDown(container.dispose);

    final AssistantReleaseConfig config = await container.read(
      assistantReleaseConfigProvider.future,
    );

    expect(config.stage, AssistantReleaseStage.off);
  });

  test(
    'Smart Planner availability requires planner and safety gates',
    () async {
      final ProviderContainer enabled = _container(
        isProduction: true,
        releaseValues: const <String, Object?>{
          'assistant_release_stage': 'general',
        },
      );
      final ProviderContainer plannerBlocked = _container(
        isProduction: true,
        releaseValues: const <String, Object?>{
          'assistant_release_stage': 'general',
          'kill_assistant_smart_planner_v2': true,
        },
      );
      final ProviderContainer safetyBlocked = _container(
        isProduction: true,
        releaseValues: const <String, Object?>{
          'assistant_release_stage': 'general',
          'kill_assistant_safety_critic': true,
        },
      );
      addTearDown(enabled.dispose);
      addTearDown(plannerBlocked.dispose);
      addTearDown(safetyBlocked.dispose);

      expect(
        await enabled.read(smartPlannerAvailabilityProvider.future),
        isTrue,
      );
      expect(
        await plannerBlocked.read(smartPlannerAvailabilityProvider.future),
        isFalse,
      );
      expect(
        await safetyBlocked.read(smartPlannerAvailabilityProvider.future),
        isFalse,
      );
    },
  );
}

ProviderContainer _container({
  required bool isProduction,
  Map<String, Object?> releaseValues = const <String, Object?>{
    'assistant_release_stage': 'off',
  },
}) {
  return ProviderContainer(
    overrides: [
      remoteConfigServiceProvider.overrideWithValue(
        RemoteConfigService(initialValues: releaseValues),
      ),
      intelligenceStateProvider.overrideWith(
        (Ref ref) => IntelligenceState(
          environment: EnvironmentState(
            appName: 'ChronoSpark',
            appFlavor: isProduction ? 'prod' : 'qa',
            isProduction: isProduction,
            isSupabaseConfigured: false,
          ),
          flags: const FeatureFlagsState(
            verboseLogs: false,
            analyticsEnabled: false,
            mockMode: true,
            mockLoginEnabled: true,
            paywallDisabled: true,
            testerFullAccess: true,
          ),
          auth: const AuthStateSnapshot(
            hasMockSignIn: true,
            hasAuthenticatedUser: false,
          ),
          mockLogin: const MockLoginConfigState(email: '', password: ''),
        ),
      ),
    ],
  );
}
