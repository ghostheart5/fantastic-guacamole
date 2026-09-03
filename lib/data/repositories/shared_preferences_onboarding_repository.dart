import 'package:fantastic_guacamole/domain/interfaces/i_onboarding_preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef SharedPreferencesLoader = Future<SharedPreferences> Function();

class SharedPreferencesOnboardingRepository
    implements IOnboardingPreferencesRepository {
  SharedPreferencesOnboardingRepository({
    SharedPreferencesLoader? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  final SharedPreferencesLoader _preferencesLoader;

  @override
  Future<void> markWelcomeComplete() async {
    final SharedPreferences preferences = await _preferencesLoader();
    await preferences.setBool(onboardingWelcomeCompleteStorageKey, true);
  }

  @override
  Future<void> markOnboardingComplete({required int contentVersion}) async {
    final SharedPreferences preferences = await _preferencesLoader();
    await preferences.setBool(onboardingCompleteStorageKey, true);
    await preferences.setInt(
      onboardingContentVersionStorageKey,
      contentVersion,
    );
  }

  @override
  Future<void> resetWelcome() async {
    final SharedPreferences preferences = await _preferencesLoader();
    await preferences.setBool(onboardingWelcomeCompleteStorageKey, false);
  }

  @override
  Future<void> resetFirstSetup() async {
    final SharedPreferences preferences = await _preferencesLoader();
    await preferences.setBool(onboardingCompleteStorageKey, false);
    await preferences.setBool(onboardingWelcomeCompleteStorageKey, false);
    await preferences.setInt(onboardingContentVersionStorageKey, 0);
  }
}
