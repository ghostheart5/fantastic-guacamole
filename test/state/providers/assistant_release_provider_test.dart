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
}

ProviderContainer _container({required bool isProduction}) {
  return ProviderContainer(
    overrides: [
      remoteConfigServiceProvider.overrideWithValue(
        RemoteConfigService(
          initialValues: const <String, Object?>{
            'assistant_release_stage': 'off',
          },
        ),
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
