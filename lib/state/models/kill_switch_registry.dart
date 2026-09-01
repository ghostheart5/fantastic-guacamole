import 'package:flutter/foundation.dart';

@immutable
class KillSwitchRegistry {
  KillSwitchRegistry({Set<String> disabledCapabilities = const <String>{}})
    : disabledCapabilities = Set<String>.unmodifiable(disabledCapabilities);

  final Set<String> disabledCapabilities;

  bool isDisabled(String capability) =>
      disabledCapabilities.contains(capability);

  KillSwitchRegistry copyWith({Set<String>? disabledCapabilities}) {
    return KillSwitchRegistry(
      disabledCapabilities: disabledCapabilities ?? this.disabledCapabilities,
    );
  }
}
