import 'dart:developer' as dev;

import '../config/env.dart';

class Logger {
  static const String _name = 'ChronoSpark';

  static void debug(String event, {Map<String, Object?>? data}) {
    if (!Env.enableVerboseLogs) {
      return;
    }
    final String payload = data != null ? ' | ${_formatData(data)}' : '';
    dev.log('[DEBUG] $event$payload', name: _name, level: 500);
  }

  static void info(String message, {Map<String, Object?>? data}) {
    if (Env.enableVerboseLogs) {
      final String payload = data != null ? ' | ${_formatData(data)}' : '';
      dev.log('[INFO] $message$payload', name: _name, level: 800);
    }
  }

  static void warning(String message, {Map<String, Object?>? data}) {
    final String payload = data != null ? ' | ${_formatData(data)}' : '';
    dev.log('[WARN] $message$payload', name: _name, level: 900);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    dev.log(
      '[ERROR] $message',
      name: _name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static String _formatData(Map<String, Object?> data) {
    return data.entries.map((MapEntry<String, Object?> e) => '${e.key}=${e.value}').join(', ');
  }
}
