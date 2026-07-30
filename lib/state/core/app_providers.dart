import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:fantastic_guacamole/state/core/state_bootstrap.dart'
    show stateBootstrapProvider;
export 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
export 'package:fantastic_guacamole/state/providers/energy_provider.dart';
export 'package:fantastic_guacamole/state/providers/learning_history_provider.dart';
export 'package:fantastic_guacamole/state/providers/notification_provider.dart';
export 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
export 'package:fantastic_guacamole/state/providers/session_score_provider.dart';
export 'package:fantastic_guacamole/state/providers/si_memory_provider.dart';
export 'package:fantastic_guacamole/state/providers/sync_provider.dart';
export 'package:fantastic_guacamole/state/providers/task_provider.dart';

const String onboardingCompleteStorageKey = 'onboarding_complete';
const String onboardingContentVersionStorageKey = 'onboarding_content_version';
const String onboardingStepStorageKey = 'onboarding_step_index';
const String creatorFirstItemCreatedStorageKey =
  'creator_first_item_created_v1';
const String timelineFirstActionCompletedStorageKey =
    'timeline_first_action_completed_v1';

enum OnboardingStatus { unknown, incomplete, complete }

String onboardingCompleteStorageKeyForUser(String userId) {
  return '${onboardingCompleteStorageKey}_$userId';
}

String onboardingContentVersionStorageKeyForUser(String userId) {
  return '${onboardingContentVersionStorageKey}_$userId';
}

String onboardingStepStorageKeyForUser(String userId) {
  return '${onboardingStepStorageKey}_$userId';
}

String creatorFirstItemCreatedStorageKeyForUser(String userId) {
  return '${creatorFirstItemCreatedStorageKey}_$userId';
}

String timelineFirstActionCompletedStorageKeyForUser(String userId) {
  return '${timelineFirstActionCompletedStorageKey}_$userId';
}

final soundEnabledProvider = NotifierProvider<SoundEnabledNotifier, bool>(
  SoundEnabledNotifier.new,
);
final onboardingCompleteProvider =
    NotifierProvider<OnboardingCompleteNotifier, bool>(
      OnboardingCompleteNotifier.new,
    );
final onboardingStatusProvider =
    NotifierProvider<OnboardingStatusNotifier, OnboardingStatus>(
      OnboardingStatusNotifier.new,
    );
final creatorFirstItemCreatedProvider =
    NotifierProvider<CreatorFirstItemCreatedNotifier, bool>(
      CreatorFirstItemCreatedNotifier.new,
    );
final timelineFirstActionCompletedProvider =
    NotifierProvider<TimelineFirstActionCompletedNotifier, bool>(
      TimelineFirstActionCompletedNotifier.new,
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

class OnboardingStatusNotifier extends Notifier<OnboardingStatus> {
  @override
  OnboardingStatus build() => OnboardingStatus.unknown;

  void set(OnboardingStatus value) => state = value;
}

class CreatorFirstItemCreatedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

class TimelineFirstActionCompletedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}
