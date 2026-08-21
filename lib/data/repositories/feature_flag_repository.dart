import 'package:fantastic_guacamole/data/services/remote_config_service.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/state/models/experiment_assignment.dart';
import 'package:fantastic_guacamole/state/models/kill_switch_registry.dart';

class FeatureFlagRepository {
  FeatureFlagRepository(this._remoteConfigService);

  final RemoteConfigService _remoteConfigService;

  static const Map<String, bool> _defaultFlags = <String, bool>{
    'daily_reflection_tutorial_enabled': true,
    'new_paywall_copy_enabled': false,
  };

  static const Set<String> _defaultKillSwitches = <String>{
    'assistant_smart_planner_v2',
    'assistant_si_console_v2',
    'assistant_governed_memory',
    'assistant_safety_critic',
  };

  static const Map<String, String> _defaultVariants = <String, String>{
    'nexus_header_experiment': 'control',
    'settings_reflection_prompt_experiment': 'control',
  };

  Future<Map<String, bool>> loadFlags() async {
    await _remoteConfigService.refresh();
    final Map<String, bool> merged = <String, bool>{};

    for (final MapEntry<String, bool> entry in _defaultFlags.entries) {
      merged[entry.key] = _remoteConfigService.getBool(
        'flag_${entry.key}',
        defaultValue: entry.value,
      );
    }

    return merged;
  }

  Future<KillSwitchRegistry> loadKillSwitchRegistry() async {
    await _remoteConfigService.refresh();
    final Set<String> disabled = <String>{};

    for (final String capability in _defaultKillSwitches) {
      final bool isOff = _remoteConfigService.getBool(
        'kill_$capability',
        defaultValue: false,
      );
      if (isOff) {
        disabled.add(capability);
      }
    }

    return KillSwitchRegistry(disabledCapabilities: disabled);
  }

  Future<List<ExperimentAssignment>> loadAssignments() async {
    await _remoteConfigService.refresh();
    final List<ExperimentAssignment> assignments = <ExperimentAssignment>[];

    for (final MapEntry<String, String> entry in _defaultVariants.entries) {
      final String variant = _remoteConfigService.getString(
        'exp_${entry.key}',
        defaultValue: entry.value,
      );
      final int bucket = _remoteConfigService.getInt(
        'bucket_${entry.key}',
        defaultValue: 0,
      );
      assignments.add(
        ExperimentAssignment(
          experimentId: entry.key,
          variant: variant,
          bucket: bucket,
          isControl: variant == 'control',
        ),
      );
    }

    return assignments;
  }

  /// Loads one atomic assistant release snapshot. A malformed stage, cohort,
  /// or canary value is rejected by the domain object and disables all four
  /// capabilities instead of partially applying an unsafe configuration.
  Future<AssistantReleaseConfig> loadAssistantReleaseConfig() async {
    await _remoteConfigService.refresh();
    final String internalDigests = _remoteConfigService.getString(
      'assistant_release_internal_account_digests',
    );
    final Map<AssistantReleaseCapability, String>
    killKeys = <AssistantReleaseCapability, String>{
      AssistantReleaseCapability.smartPlannerV2:
          'kill_assistant_smart_planner_v2',
      AssistantReleaseCapability.siConsoleV2: 'kill_assistant_si_console_v2',
      AssistantReleaseCapability.governedMemory:
          'kill_assistant_governed_memory',
      AssistantReleaseCapability.safetyCritic: 'kill_assistant_safety_critic',
    };
    final Set<AssistantReleaseCapability> rollbacks =
        <AssistantReleaseCapability>{};
    for (final MapEntry<AssistantReleaseCapability, String> entry
        in killKeys.entries) {
      if (_remoteConfigService.getBool(entry.value, defaultValue: false)) {
        rollbacks.add(entry.key);
      }
    }
    return AssistantReleaseConfig.fromRemote(
      stage: _remoteConfigService.getString(
        'assistant_release_stage',
        defaultValue: 'general',
      ),
      canaryBasisPoints: _remoteConfigService.getInt(
        'assistant_release_canary_basis_points',
        defaultValue: 0,
      ),
      shadowEvaluationEnabled: _remoteConfigService.getBool(
        'assistant_shadow_evaluation_enabled',
        defaultValue: false,
      ),
      internalAccountDigests: internalDigests.split(','),
      rollbackCapabilities: rollbacks,
    );
  }
}
