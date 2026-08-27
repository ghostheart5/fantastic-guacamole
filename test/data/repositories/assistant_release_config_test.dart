import 'package:fantastic_guacamole/data/repositories/feature_flag_repository.dart';
import 'package:fantastic_guacamole/data/services/remote_config_service.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing remote release snapshot remains off', () async {
    final AssistantReleaseConfig config = await FeatureFlagRepository(
      RemoteConfigService(),
    ).loadAssistantReleaseConfig();

    expect(config.configurationValid, isTrue);
    expect(config.stage, AssistantReleaseStage.off);
    expect(config.canaryBasisPoints, 0);
    expect(config.shadowEvaluationEnabled, isFalse);
    expect(config.rollbackCapabilities, isEmpty);
  });

  test('repository maps one atomic controlled-release snapshot', () async {
    final RemoteConfigService remote = RemoteConfigService(
      initialValues: <String, Object?>{
        'assistant_release_stage': 'canary',
        'assistant_release_canary_basis_points': 750,
        'assistant_shadow_evaluation_enabled': true,
        'assistant_release_internal_account_digests': 'a' * 64,
        'kill_assistant_si_console_v2': true,
      },
    );

    final AssistantReleaseConfig config = await FeatureFlagRepository(
      remote,
    ).loadAssistantReleaseConfig();

    expect(config.configurationValid, isTrue);
    expect(config.stage, AssistantReleaseStage.canary);
    expect(config.canaryBasisPoints, 750);
    expect(config.shadowEvaluationEnabled, isTrue);
    expect(config.internalAccountDigests, <String>{'a' * 64});
    expect(config.rollbackCapabilities, <AssistantReleaseCapability>{
      AssistantReleaseCapability.siConsoleV2,
    });
  });

  test('invalid remote snapshot disables all capabilities', () async {
    final RemoteConfigService remote = RemoteConfigService(
      initialValues: const <String, Object?>{
        'assistant_release_stage': 'canary',
        'assistant_release_canary_basis_points': 10001,
      },
    );

    final AssistantReleaseConfig config = await FeatureFlagRepository(
      remote,
    ).loadAssistantReleaseConfig();

    expect(config.configurationValid, isFalse);
    expect(config.stage, AssistantReleaseStage.off);
    expect(
      config.rollbackCapabilities,
      AssistantReleaseCapability.values.toSet(),
    );
  });
}
