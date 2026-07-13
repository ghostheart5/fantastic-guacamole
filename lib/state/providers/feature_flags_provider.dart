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

class RemotePaywallConfig {
  const RemotePaywallConfig({
    required this.enabled,
    required this.titleOverride,
    required this.bodyOverride,
  });

  final bool enabled;
  final String titleOverride;
  final String bodyOverride;

  bool get hasTitleOverride => titleOverride.trim().isNotEmpty;
  bool get hasBodyOverride => bodyOverride.trim().isNotEmpty;
}

class RemoteAnnouncement {
  const RemoteAnnouncement({
    required this.enabled,
    required this.title,
    required this.message,
    required this.level,
  });

  final bool enabled;
  final String title;
  final String message;
  final String level;

  bool get hasContent => _isMeaningfulRemoteText(message);

  bool get hasTitle => _isMeaningfulRemoteText(title);
}

final featureFlagsProvider = FutureProvider<Map<String, bool>>((Ref ref) async {
  return ref.read(featureFlagRepositoryProvider).loadFlags();
});

final remotePaywallConfigProvider = FutureProvider<RemotePaywallConfig>((
  Ref ref,
) async {
  final RemoteConfigService remoteConfig = ref.read(
    remoteConfigServiceProvider,
  );
  await remoteConfig.refresh();
  return RemotePaywallConfig(
    enabled: remoteConfig.getBool('paywall_enabled', defaultValue: true),
    titleOverride: remoteConfig.getString('paywall_title_override'),
    bodyOverride: remoteConfig.getString('paywall_body_override'),
  );
});

final remoteAnnouncementProvider = FutureProvider<RemoteAnnouncement>((
  Ref ref,
) async {
  final RemoteConfigService remoteConfig = ref.read(
    remoteConfigServiceProvider,
  );
  await remoteConfig.refresh();
  return RemoteAnnouncement(
    enabled: remoteConfig.getBool('announcement_enabled', defaultValue: false),
    title: _sanitizeRemoteText(remoteConfig.getString('announcement_title')),
    message: _sanitizeRemoteText(
      remoteConfig.getString('announcement_message'),
    ),
    level: _sanitizeRemoteText(
      remoteConfig.getString('announcement_level', defaultValue: 'info'),
    ),
  );
});

String _sanitizeRemoteText(String raw) {
  final String normalized = raw.trim();
  if (!_isMeaningfulRemoteText(normalized)) {
    return '';
  }
  return normalized;
}

bool _isMeaningfulRemoteText(String raw) {
  final String normalized = raw.trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }
  return normalized != 'null' && normalized != 'undefined';
}

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
