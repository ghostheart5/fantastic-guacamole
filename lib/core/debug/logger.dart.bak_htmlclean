import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/utils/date_time_formats.dart';
import 'package:fantastic_guacamole/core/utils/helpers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class Logger {
  static bool enabled = true;
  static bool errorOutputEnabled = true;

  static void log(String tag, Object? message) {
    if (!enabled || (!kDebugMode && !Env.enableVerboseLogs)) return;
    debugPrint('[${_now()}][$tag] ${redactSensitive(safeString(message))}');
  }

  static void info(Object? message) {
    if (!enabled || (!kDebugMode && !Env.enableVerboseLogs)) return;
    debugPrint('[${_now()}][INFO] ${redactSensitive(safeString(message))}');
  }

  static void warn(Object? message) {
    if (!enabled || (!kDebugMode && !Env.enableVerboseLogs)) return;
    debugPrint('[${_now()}][WARN] ${redactSensitive(safeString(message))}');
  }

  // Errors always print regardless of the enabled flag and report to Crashlytics.
  static void error(Object? message, [Object? exception]) {
    if (errorOutputEnabled) {
      debugPrint(
        '[${_now()}][ERROR] ${redactSensitive(safeString(message))}'
        '${exception != null ? ' | ${redactSensitive(safeString(exception))}' : ''}',
      );
    }
    if (_supportsCrashlytics && Firebase.apps.isNotEmpty) {
      FirebaseCrashlytics.instance.recordError(
        Exception(redactSensitive(safeString(exception ?? message))),
        exception != null ? StackTrace.current : null,
        reason: exception != null ? redactSensitive(safeString(message)) : null,
        fatal: false,
      );
    }
  }

  static void errorCategory(
    String category,
    Object? message, [
    Object? exception,
    StackTrace? stackTrace,
  ]) {
    if (errorOutputEnabled) {
      debugPrint(
        '[${_now()}][ERROR][$category] ${redactSensitive(safeString(message))}'
        '${exception != null ? ' | ${redactSensitive(safeString(exception))}' : ''}',
      );
    }
    if (_supportsCrashlytics && Firebase.apps.isNotEmpty) {
      FirebaseCrashlytics.instance.recordError(
        exception ?? Exception(redactSensitive(safeString(message))),
        stackTrace,
        reason: '$category: ${redactSensitive(safeString(message))}',
        fatal: false,
      );
    }
  }

  static Future<T> withMutedErrors<T>(Future<T> Function() action) async {
    final bool previous = errorOutputEnabled;
    errorOutputEnabled = false;
    try {
      return await action();
    } finally {
      errorOutputEnabled = previous;
    }
  }

  static String _now() => DateTimeFormats.reportTimestamp(DateTime.now());

  static String redactSensitive(String value) {
    return value
        .replaceAll(
          RegExp(
            r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
            caseSensitive: false,
          ),
          '[redacted-email]',
        )
        .replaceAll(
          RegExp(r'\bBearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
          'Bearer [redacted-token]',
        )
        .replaceAllMapped(
          RegExp(
            r'((?:access|refresh|purchase|verification|auth)[_-]?token\s*[:=]\s*)[^\s,}]+',
            caseSensitive: false,
          ),
          (Match match) => '${match.group(1)}[redacted-token]',
        )
        .replaceAllMapped(
          RegExp(r'(password\s*[:=]\s*)[^\s,}]+', caseSensitive: false),
          (Match match) => '${match.group(1)}[redacted-password]',
        )
        .replaceAllMapped(
          RegExp(
            r'''(["'](?:access|refresh|purchase|verification|auth)[_-]?token["']\s*:\s*["'])[^"']+(["'])''',
            caseSensitive: false,
          ),
          (Match match) => '${match.group(1)}[redacted-token]${match.group(2)}',
        )
        .replaceAllMapped(
          RegExp(
            r'''(["']password["']\s*:\s*["'])[^"']+(["'])''',
            caseSensitive: false,
          ),
          (Match match) =>
              '${match.group(1)}[redacted-password]${match.group(2)}',
        )
        .replaceAllMapped(
          RegExp(
            r'''(["'](?:api[_-]?key|apikey|secret|client[_-]?secret)["']\s*:\s*["'])[^"']+(["'])''',
            caseSensitive: false,
          ),
          (Match match) =>
              '${match.group(1)}[redacted-secret]${match.group(2)}',
        )
        .replaceAll(RegExp(r'AIza[0-9A-Za-z\-_]{35}'), '[redacted-api-key]');
  }

  static bool get _supportsCrashlytics =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);
}
