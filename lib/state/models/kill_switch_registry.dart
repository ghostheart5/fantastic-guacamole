import 'package:flutter/foundation.dart';

@immutable
class KillSwitchRegistry {
  const KillSwitchRegistry({this.disabledCapabilities = const <String>{}});

  final Set<String> disabledCapabilities;

  bool isDisabled(String capability) =>
      disabledCapabilities.contains(capability);

  KillSwitchRegistry copyWith({Set<String>? disabledCapabilities}) {
    return KillSwitchRegistry(
      disabledCapabilities: disabledCapabilities ?? this.disabledCapabilities,
    );
  }
}
