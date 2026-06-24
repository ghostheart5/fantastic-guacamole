import 'package:flutter/foundation.dart';

class Env {
  static const String appName = 'ChronoSpark';
  static const String appFlavor = String.fromEnvironment(
    'CHRONOSPARK_APP_FLAVOR',
    defaultValue: 'dev',
  );
  static const bool enableVerboseLogs = !kReleaseMode;

  /// True only in verified production release builds.
  static bool get isProduction =>
      kReleaseMode && appFlavor.toLowerCase() == 'prod';

  /// Mock login is never allowed in release builds.
  static bool get isMockLoginEnabled {
    if (kReleaseMode) return false;
    return const bool.fromEnvironment(
      'CHRONOSPARK_ENABLE_MOCK_LOGIN',
      defaultValue: false,
    );
  }
}
