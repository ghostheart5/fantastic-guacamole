import 'dart:async';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/utils/date_time_formats.dart';
import 'package:fantastic_guacamole/core/utils/helpers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class Logger {
  static bool enabled = true;
  static bool errorOutputEnabled = true;

  /// Free-form diagnostic text is available in development builds and in
  /// builds where verbose logging was deliberately enabled at compile time.
  /// Normal release builds receive fixed diagnostic codes only.
  static bool get freeFormOutputEnabled => resolveFreeFormOutputEnabled(
    isDebugMode: kDebugMode,
    verboseLogsEnabled: _verboseLogsEnabled,
  );

  @visibleForTesting
  static bool resolveFreeFormOutputEnabled({
    required bool isDebugMode,
    required bool verboseLogsEnabled,
  }) => isDebugMode || verboseLogsEnabled;

  static void log(String tag, Object? message) {
    if (!enabled || !freeFormOutputEnabled) return;
    debugPrint('[${_now()}][$tag] ${redactSensitive(safeString(message))}');
  }

  static void info(Object? message) {
    if (!enabled || !freeFormOutputEnabled) return;
    debugPrint('[${_now()}][INFO] ${redactSensitive(safeString(message))}');
  }

  static void warn(Object? message) {
    if (!enabled || !freeFormOutputEnabled) return;
    debugPrint('[${_now()}][WARN] ${redactSensitive(safeString(message))}');
  }

  static void error(Object? message, [Object? exception]) {
    errorCode(
      code: 'logger.error',
      debugMessage: message,
      exception: exception,
      stackTrace: exception != null ? StackTrace.current : null,
    );
  }

  static void errorCategory(
    String category,
    Object? message, [
    Object? exception,
    StackTrace? stackTrace,
  ]) {
    errorCode(
      code: 'logger.categorized_error',
      debugMessage: '[$category] ${safeString(message)}',
      exception: exception,
      stackTrace: stackTrace,
    );
  }

  /// Records a stable diagnostic code while keeping arbitrary details out of
  /// normal release output. [code] must be a fixed, non-sensitive call-site
  /// constant; [debugMessage], [exception], and [stackTrace] are emitted only
  /// when [freeFormOutputEnabled] is true.
  static void errorCode({
    required String code,
    Object? debugMessage,
    Object? exception,
    StackTrace? stackTrace,
    bool fatal = false,
    String? debugMarker,
  }) {
    final String safeCode = _safeCode(code);
    if (errorOutputEnabled) {
      final String timestamp = _now();
      for (final String line in resolveLocalDiagnosticOutput(
        code: safeCode,
        debugMessage: debugMessage,
        exception: exception,
        stackTrace: stackTrace,
        debugMarker: debugMarker,
        isDebugMode: kDebugMode,
        verboseLogsEnabled: _verboseLogsEnabled,
      )) {
        debugPrint('[$timestamp]$line');
      }
    }
    recordDiagnosticCode(code: safeCode, stackTrace: stackTrace, fatal: fatal);
  }

  @visibleForTesting
  static List<String> resolveLocalDiagnosticOutput({
    required String code,
    Object? debugMessage,
    Object? exception,
    StackTrace? stackTrace,
    String? debugMarker,
    required bool isDebugMode,
    required bool verboseLogsEnabled,
  }) {
    final String safeCode = _safeCode(code);
    if (!resolveFreeFormOutputEnabled(
      isDebugMode: isDebugMode,
      verboseLogsEnabled: verboseLogsEnabled,
    )) {
      return <String>['[ERROR][$safeCode]'];
    }

    final String marker = redactSensitive(debugMarker?.trim() ?? '');
    final String message = redactSensitive(safeString(debugMessage)).trim();
    final String exceptionText = exception == null
        ? ''
        : redactSensitive(safeString(exception)).trim();
    final String stackText = stackTrace == null
        ? ''
        : redactSensitive(stackTrace.toString()).trim();
    final StringBuffer detail = StringBuffer('[ERROR][$safeCode]');
    if (message.isNotEmpty) {
      detail.write(' $message');
    }
    if (exceptionText.isNotEmpty) {
      detail.write(' | $exceptionText');
    }

    final List<String> output = <String>[];
    if (marker.isNotEmpty) {
      output.add('$marker >>> ${detail.toString()}');
    } else {
      output.add(detail.toString());
    }
    if (stackText.isNotEmpty) {
      output.add('[STACK][$safeCode] $stackText');
    }
    if (marker.isNotEmpty) {
      output.add('$marker <<<');
    }
    return List<String>.unmodifiable(output);
  }

  // Keep free-form breadcrumbs on device only. A generic remote breadcrumb is
  // not useful enough to justify sending user-visible or server-supplied text.
  static void breadcrumb(String message) {
    log('Breadcrumb', message);
  }

  static void recordDiagnosticCode({
    required String code,
    StackTrace? stackTrace,
    bool fatal = false,
  }) {
    if (!_supportsCrashlytics || Firebase.apps.isEmpty) {
      return;
    }
    final String safeCode = _safeCode(code);
    unawaited(
      FirebaseCrashlytics.instance
          .recordError(
            StateError('ChronoSpark diagnostic: $safeCode'),
            stackTrace,
            reason: safeCode,
            fatal: fatal,
          )
          .catchError((Object _) {}),
    );
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

  static bool get _verboseLogsEnabled {
    try {
      return Env.enableVerboseLogs;
    } on Object {
      // Logging must not turn invalid startup configuration into another
      // failure while the original error is being reported.
      return false;
    }
  }

  static String _safeCode(String value) {
    final String normalized = value.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9._-]'),
      '_',
    );
    if (normalized.isEmpty) {
      return 'unclassified';
    }
    final int end = normalized.length > 64 ? 64 : normalized.length;
    return normalized.substring(0, end);
  }

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
      Env.enableCrashReporting &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);
}
