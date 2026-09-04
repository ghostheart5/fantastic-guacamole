const String onboardingCompleteStorageKey = 'onboarding_complete';
const String onboardingContentVersionStorageKey = 'onboarding_content_version';
const String onboardingWelcomeCompleteStorageKey =
    'onboarding_welcome_complete';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Onboarding
///
/// Device-level persistence used by the first-run flow.
///
/// Account-owned onboarding state remains separate. This contract only owns
/// the device-wide routing markers read during application startup.
abstract interface class IOnboardingPreferencesRepository {
  Future<void> markWelcomeComplete();

  Future<void> markOnboardingComplete({required int contentVersion});

  Future<void> resetWelcome();

  Future<void> resetFirstSetup();
}
