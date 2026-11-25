import 'package:fantastic_guacamole/app/startup/app_bootstrap.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_onboarding_preferences_repository.dart';
import 'package:fantastic_guacamole/features/onboarding/domain/onboarding_content_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'an older stored content version keeps an existing install complete',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        onboardingCompleteStorageKey: true,
        onboardingWelcomeCompleteStorageKey: true,
        onboardingContentVersionStorageKey:
            OnboardingContentContract.currentVersion - 1,
      });

      final PrefsLoadResult result = await loadStartupPrefsForTest(
        StartupCancellationToken(),
      );

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(result.hasOnboarded, isTrue);
      // The device flag is what migrates an existing install to its account:
      // a content bump must leave it alone.
      expect(prefs.getBool(onboardingCompleteStorageKey), isTrue);
      expect(
        prefs.getInt(onboardingContentVersionStorageKey),
        OnboardingContentContract.currentVersion,
      );
    },
  );
}
