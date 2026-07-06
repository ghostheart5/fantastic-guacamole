import 'package:fantastic_guacamole/data/services/remote_config_service.dart';
import 'package:fantastic_guacamole/state/models/experiment_assignment.dart';
import 'package:fantastic_guacamole/state/models/kill_switch_registry.dart';

class FeatureFlagRepository {
  FeatureFlagRepository(this._remoteConfigService);

  final RemoteConfigService _remoteConfigService;

  static const Map<String, bool> _defaultFlags = <String, bool>{
    'tutorial_enabled': true,
    'nexus_micro_tutorial_enabled': true,
    'daily_reflection_tutorial_enabled': true,
    'new_paywall_copy_enabled': false,
  };

  static const Set<String> _defaultKillSwitches = <String>{};

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
}
