export 'package:fantastic_guacamole/domain/interfaces/i_onboarding_preferences_repository.dart'
    show
        onboardingCompleteStorageKey,
        onboardingContentVersionStorageKey,
        onboardingWelcomeCompleteStorageKey;

import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:fantastic_guacamole/state/core/state_bootstrap.dart'
    show stateBootstrapProvider;
export 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
export 'package:fantastic_guacamole/state/providers/energy_provider.dart';
export 'package:fantastic_guacamole/state/providers/learning_history_provider.dart';
export 'package:fantastic_guacamole/state/providers/notification_provider.dart';
export 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
export 'package:fantastic_guacamole/state/providers/completion_score_provider.dart';
export 'package:fantastic_guacamole/state/providers/si_memory_provider.dart';
export 'package:fantastic_guacamole/state/providers/sync_provider.dart';
export 'package:fantastic_guacamole/state/providers/task_provider.dart';

final soundEnabledProvider = NotifierProvider<SoundEnabledNotifier, bool>(
  SoundEnabledNotifier.new,
);
final onboardingCompleteProvider =
    NotifierProvider<OnboardingCompleteNotifier, bool>(
      OnboardingCompleteNotifier.new,
    );
final onboardingWelcomeCompleteProvider =
    NotifierProvider<OnboardingWelcomeCompleteNotifier, bool>(
      OnboardingWelcomeCompleteNotifier.new,
    );

class SoundEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool value) => state = value;
}

class OnboardingCompleteNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

class OnboardingWelcomeCompleteNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}
