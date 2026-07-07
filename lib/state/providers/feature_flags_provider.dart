import 'package:fantastic_guacamole/data/repositories/feature_flag_repository.dart';
import 'package:fantastic_guacamole/data/services/remote_config_service.dart';
import 'package:fantastic_guacamole/state/models/kill_switch_registry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final remoteConfigServiceProvider = Provider<RemoteConfigService>((_) {
  return RemoteConfigService();
});

final featureFlagRepositoryProvider = Provider<FeatureFlagRepository>((
  Ref ref,
) {
  return FeatureFlagRepository(ref.read(remoteConfigServiceProvider));
});

final featureFlagsProvider = FutureProvider<Map<String, bool>>((Ref ref) async {
  return ref.read(featureFlagRepositoryProvider).loadFlags();
});

final featureFlagEnabledProvider = Provider.family<bool, String>((
  Ref ref,
  String flagKey,
) {
  final AsyncValue<Map<String, bool>> flagsAsync = ref.watch(
    featureFlagsProvider,
  );
  return flagsAsync.maybeWhen(
    data: (Map<String, bool> flags) => flags[flagKey] ?? false,
    orElse: () => false,
  );
});

final killSwitchRegistryProvider = FutureProvider<KillSwitchRegistry>((
  Ref ref,
) async {
  return ref.read(featureFlagRepositoryProvider).loadKillSwitchRegistry();
});

final killSwitchActiveProvider = Provider.family<bool, String>((
  Ref ref,
  String capability,
) {
  final AsyncValue<KillSwitchRegistry> registryAsync = ref.watch(
    killSwitchRegistryProvider,
  );
  return registryAsync.maybeWhen(
    data: (KillSwitchRegistry registry) => registry.isDisabled(capability),
    orElse: () => false,
  );
});
