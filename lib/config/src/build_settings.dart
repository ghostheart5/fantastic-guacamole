part of '../env.dart';

abstract final class _BuildSettings {
  static const String _appFlavorDefine = String.fromEnvironment(
    'CHRONOSPARK_APP_FLAVOR',
    defaultValue: 'prod',
  );
  static const bool _hasAppFlavorDefine = bool.hasEnvironment(
    'CHRONOSPARK_APP_FLAVOR',
  );
  static const bool _enableVerboseLogsDefine = bool.fromEnvironment(
    'CHRONOSPARK_VERBOSE_LOGS',
    defaultValue: false,
  );
  static const String _enableVerboseLogsRawDefine = String.fromEnvironment(
    'CHRONOSPARK_VERBOSE_LOGS',
  );
  static const bool _hasEnableVerboseLogsDefine = bool.hasEnvironment(
    'CHRONOSPARK_VERBOSE_LOGS',
  );
  static const bool _enableCrashReportingDefine = bool.fromEnvironment(
    'CHRONOSPARK_ENABLE_CRASH_REPORTING',
    defaultValue: true,
  );
  static const String _enableCrashReportingRawDefine = String.fromEnvironment(
    'CHRONOSPARK_ENABLE_CRASH_REPORTING',
  );
  static const bool _hasEnableCrashReportingDefine = bool.hasEnvironment(
    'CHRONOSPARK_ENABLE_CRASH_REPORTING',
  );
  static const bool _enableAnalyticsDefine = bool.fromEnvironment(
    'CHRONOSPARK_ENABLE_ANALYTICS',
    defaultValue: true,
  );
  static const String _enableAnalyticsRawDefine = String.fromEnvironment(
    'CHRONOSPARK_ENABLE_ANALYTICS',
  );
  static const bool _hasEnableAnalyticsDefine = bool.hasEnvironment(
    'CHRONOSPARK_ENABLE_ANALYTICS',
  );
  static const String _appLinksAndroidSha256Define = String.fromEnvironment(
    'CHRONOSPARK_ANDROID_SHA256_CERT',
    defaultValue: '',
  );
  static const bool _hasAppLinksAndroidSha256Define = bool.hasEnvironment(
    'CHRONOSPARK_ANDROID_SHA256_CERT',
  );
  static const String _appLinksIosTeamIdDefine = String.fromEnvironment(
    'CHRONOSPARK_IOS_TEAM_ID',
    defaultValue: '',
  );
  static const bool _hasAppLinksIosTeamIdDefine = bool.hasEnvironment(
    'CHRONOSPARK_IOS_TEAM_ID',
  );

  static String get appFlavor => Env._readRiskString(
    'CHRONOSPARK_APP_FLAVOR',
    _appFlavorDefine,
    defineProvided: _hasAppFlavorDefine,
  );

  static bool get enableVerboseLogs => Env._readRiskBool(
    'CHRONOSPARK_VERBOSE_LOGS',
    _enableVerboseLogsDefine,
    defineProvided: _hasEnableVerboseLogsDefine,
    rawDefineValue: _enableVerboseLogsRawDefine,
  );

  static bool get enableCrashReporting => Env._readBool(
    'CHRONOSPARK_ENABLE_CRASH_REPORTING',
    _enableCrashReportingDefine,
    defineProvided: _hasEnableCrashReportingDefine,
    rawDefineValue: _enableCrashReportingRawDefine,
  );

  static bool get enableAnalytics => Env._readBool(
    'CHRONOSPARK_ENABLE_ANALYTICS',
    _enableAnalyticsDefine,
    defineProvided: _hasEnableAnalyticsDefine,
    rawDefineValue: _enableAnalyticsRawDefine,
  );

  static String get appLinksAndroidSha256 => Env._readString(
    'CHRONOSPARK_ANDROID_SHA256_CERT',
    _appLinksAndroidSha256Define,
    defineProvided: _hasAppLinksAndroidSha256Define,
  );

  static String get appLinksIosTeamId => Env._readString(
    'CHRONOSPARK_IOS_TEAM_ID',
    _appLinksIosTeamIdDefine,
    defineProvided: _hasAppLinksIosTeamIdDefine,
  );

  static AppFlavor get flavor =>
      resolveFlavor(appFlavor, isReleaseMode: kReleaseMode);

  static AppFlavor resolveFlavor(String flavor, {required bool isReleaseMode}) {
    return AppFlavor.tryParse(flavor) ??
        (isReleaseMode ? AppFlavor.production : AppFlavor.development);
  }

  static bool resolveIsProduction(
    String flavor, {
    required bool isReleaseMode,
  }) {
    // Unknown release flavors fail closed to production so a typo cannot
    // silently disable production security gates.
    return isReleaseMode &&
        resolveFlavor(flavor, isReleaseMode: isReleaseMode).isProduction;
  }

  static bool get isProduction =>
      resolveIsProduction(appFlavor, isReleaseMode: kReleaseMode);
}
