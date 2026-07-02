import 'package:flutter/foundation.dart';

class Logger {
  static bool enabled = true;

  static void log(String tag, String message) {
    if (!enabled) return;
    debugPrint('[${_now()}][$tag] $message');
  }

  static void info(String message) {
    if (!enabled) return;
    debugPrint('[${_now()}][INFO] $message');
  }

  static void warn(String message) {
    if (!enabled) return;
    debugPrint('[${_now()}][WARN] $message');
  }

  // Errors always print regardless of the enabled flag.
  static void error(String message, [Object? exception]) {
    debugPrint(
      '[${_now()}][ERROR] $message'
      '${exception != null ? ' | $exception' : ''}',
    );
  }

  static String _now() => DateTime.now().toIso8601String();
}
