part of 'app_bootstrap.dart';

Future<void> persistOnboardingReplayRequired({
  required Future<void> Function() markOnboardingIncomplete,
  required Future<void> Function() storeContentVersion,
}) async {
  await markOnboardingIncomplete();
  await storeContentVersion();
}

Future<PrefsLoadResult> _loadPrefsSafe(
  StartupCancellationToken cancellationToken,
) async {
  bool hasOnboarded = false;
  bool hasSeenWelcome = false;

  try {
    if (cancellationToken.isCancelled) {
      return _cancelledPrefsLoadResult;
    }
    Logger.log('Startup', 'Loading local preferences...');
    RuntimeDiagnostics.record('Loading local preferences...');
    final prefs = await SharedPreferences.getInstance();
    if (cancellationToken.isCancelled) {
      return _cancelledPrefsLoadResult;
    }
    final Object? rawOnboardingComplete = prefs.get(
      onboardingCompleteStorageKey,
    );
    hasOnboarded = _coercePrefsBool(rawOnboardingComplete) ?? false;
    if (rawOnboardingComplete is String) {
      await prefs.setBool(onboardingCompleteStorageKey, hasOnboarded);
      if (cancellationToken.isCancelled) {
        return _cancelledPrefsLoadResult;
      }
    }

    final Object? rawWelcomeComplete = prefs.get(
      onboardingWelcomeCompleteStorageKey,
    );
    hasSeenWelcome = _coercePrefsBool(rawWelcomeComplete) ?? hasOnboarded;
    if (rawWelcomeComplete is String ||
        (rawWelcomeComplete == null && hasOnboarded)) {
      await prefs.setBool(onboardingWelcomeCompleteStorageKey, hasSeenWelcome);
      if (cancellationToken.isCancelled) {
        return _cancelledPrefsLoadResult;
      }
    }

    final Object? rawOnboardingVersion = prefs.get(
      onboardingContentVersionStorageKey,
    );
    final int storedOnboardingVersion =
        _coercePrefsInt(rawOnboardingVersion) ?? 0;
    if (rawOnboardingVersion is String) {
      await prefs.setInt(
        onboardingContentVersionStorageKey,
        storedOnboardingVersion,
      );
      if (cancellationToken.isCancelled) {
        return _cancelledPrefsLoadResult;
      }
    }
    final int currentOnboardingVersion =
        OnboardingContentContract.currentVersion;

    if (storedOnboardingVersion < currentOnboardingVersion) {
      hasOnboarded = false;
      await persistOnboardingReplayRequired(
        markOnboardingIncomplete: () =>
            prefs.setBool(onboardingCompleteStorageKey, false),
        storeContentVersion: () => prefs.setInt(
          onboardingContentVersionStorageKey,
          currentOnboardingVersion,
        ),
      );
      if (cancellationToken.isCancelled) {
        return _cancelledPrefsLoadResult;
      }
      Logger.log(
        'Startup',
        'Onboarding content version updated '
            '($storedOnboardingVersion -> $currentOnboardingVersion); replay required.',
      );
      RuntimeDiagnostics.record(
        'Onboarding content version updated '
        '($storedOnboardingVersion -> $currentOnboardingVersion); replay required.',
      );
    }

    Logger.log(
      'Startup',
      'Local preferences loaded. onboardingComplete=$hasOnboarded',
    );
    RuntimeDiagnostics.record(
      'Local preferences loaded. onboardingComplete=$hasOnboarded',
    );
    return PrefsLoadResult(
      hasOnboarded: hasOnboarded,
      hasSeenWelcome: hasSeenWelcome,
      issue: null,
    );
  } on TimeoutException {
    if (cancellationToken.isCancelled) {
      return _cancelledPrefsLoadResult;
    }
    Logger.errorCode(code: AppDiagnosticCode.startupPreferencesTimedOut);
    RuntimeDiagnostics.record('Local preferences initialization timed out.');
    return const PrefsLoadResult(
      hasOnboarded: false,
      hasSeenWelcome: false,
      issue: 'Local preferences initialization timed out.',
    );
  } on Object catch (error) {
    if (cancellationToken.isCancelled) {
      return _cancelledPrefsLoadResult;
    }
    Logger.errorCode(
      code: AppDiagnosticCode.startupPreferencesFailed,
      debugMessage: 'Local preferences initialization failed.',
      exception: error,
    );
    RuntimeDiagnostics.record('Local preferences initialization failed.');
    return const PrefsLoadResult(
      hasOnboarded: false,
      hasSeenWelcome: false,
      issue: 'Local preferences initialization failed. Retry from the app.',
    );
  }
}

bool? _coercePrefsBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    final String normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
  }
  if (value is num) {
    if (value == 1) {
      return true;
    }
    if (value == 0) {
      return false;
    }
  }
  return null;
}

int? _coercePrefsInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}
