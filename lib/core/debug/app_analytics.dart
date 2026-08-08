import 'dart:async';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/state/services/intelligence_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

class AppAnalytics {
  const AppAnalytics._();

  /// Firebase rejects event names longer than 40 characters and parameter
  /// names longer than 40, values longer than 100, and more than 25 params
  /// per event. Exceeding any of these previously produced an unhandled async
  /// rejection because the dispatch was unawaited with no error handler.
  static const int _maxEventNameLength = 40;
  static const int _maxParamNameLength = 40;
  static const int _maxParamValueLength = 100;
  static const int _maxParams = 25;

  static void track(
    String event, {
    Map<String, Object?> params = const <String, Object?>{},
  }) {
    final bool analyticsEnabled = const IntelligenceService()
        .environmentOnly()
        .flags
        .analyticsEnabled;
    if (!analyticsEnabled) return;

    Logger.log('Analytics', event);
    RuntimeDiagnostics.record('Analytics: $event');

    if (Firebase.apps.isNotEmpty) {
      final String name = _sanitizeEventName(event);
      if (name.isEmpty) {
        return;
      }
      final Map<String, Object>? analyticsParams = _sanitizeParams(params);
      unawaited(
        FirebaseAnalytics.instance
            .logEvent(name: name, parameters: analyticsParams)
            // Analytics must never surface as an unhandled zone error. A
            // rejected dispatch is logged and dropped.
            .catchError((Object error) {
              Logger.warn('Analytics event "$name" failed: $error');
            }),
      );
    }
  }

  /// Firebase event names must start with a letter and contain only letters,
  /// digits and underscores. Returns an empty string if nothing usable remains.
  static String _sanitizeEventName(String event) {
    final String cleaned = event
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final String trimmed = cleaned.startsWith(RegExp('[A-Za-z]'))
        ? cleaned
        : 'event_$cleaned';
    return trimmed.length > _maxEventNameLength
        ? trimmed.substring(0, _maxEventNameLength)
        : trimmed;
  }

  /// Caps parameter count, name length and value length.
  ///
  /// Values are user-authored in several call sites (goal and task titles), so
  /// they are truncated rather than trusted.
  static Map<String, Object>? _sanitizeParams(Map<String, Object?> params) {
    if (params.isEmpty) {
      return null;
    }
    final Map<String, Object> result = <String, Object>{};
    for (final MapEntry<String, Object?> entry in params.entries) {
      if (result.length >= _maxParams) {
        break;
      }
      final String key = entry.key.trim().replaceAll(
        RegExp(r'[^A-Za-z0-9_]'),
        '_',
      );
      if (key.isEmpty) {
        continue;
      }
      final String cappedKey = key.length > _maxParamNameLength
          ? key.substring(0, _maxParamNameLength)
          : key;
      final String value = entry.value?.toString() ?? '';
      result[cappedKey] = value.length > _maxParamValueLength
          ? value.substring(0, _maxParamValueLength)
          : value;
    }
    return result.isEmpty ? null : result;
  }
}
