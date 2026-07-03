import 'package:fantastic_guacamole/core/utils/helpers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class Logger {
  static bool enabled = true;

  static void log(String tag, Object? message) {
    if (!enabled) return;
    debugPrint('[${_now()}][$tag] ${safeString(message)}');
  }

  static void info(Object? message) {
    if (!enabled) return;
    debugPrint('[${_now()}][INFO] ${safeString(message)}');
  }

  static void warn(Object? message) {
    if (!enabled) return;
    debugPrint('[${_now()}][WARN] ${safeString(message)}');
  }

  // Errors always print regardless of the enabled flag and report to Crashlytics.
  static void error(Object? message, [Object? exception]) {
    debugPrint(
      '[${_now()}][ERROR] ${safeString(message)}'
      '${exception != null ? ' | ${safeString(exception)}' : ''}',
    );
    if (Firebase.apps.isNotEmpty) {
      FirebaseCrashlytics.instance.recordError(
        exception ?? message,
        exception != null ? StackTrace.current : null,
        reason: exception != null ? safeString(message) : null,
        fatal: false,
      );
    }
  }

  static String _now() => DateTime.now().toIso8601String();
}
