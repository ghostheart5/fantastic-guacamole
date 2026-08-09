import 'dart:async';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/state/services/intelligence_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppAnalytics {
  const AppAnalytics._();

  @visibleForTesting
  static Future<void> Function(String? userId)? userAttributionOverride;

  @visibleForTesting
  static Future<void> Function(String screenName)? screenViewOverride;

  static Future<void> identifySupabaseUser(String? userId) async {
    final String? normalized = userId?.trim().isEmpty == true
        ? null
        : userId?.trim();
    if (userAttributionOverride != null) {
      await userAttributionOverride!(normalized);
      return;
    }
    if (!_canUseFirebaseAnalytics || Firebase.apps.isEmpty) {
      return;
    }
    try {
      await FirebaseAnalytics.instance.setUserId(id: normalized);
      await FirebaseAnalytics.instance.setUserProperty(
        name: 'auth_source',
        value: normalized == null ? 'signed_out' : 'supabase',
      );
    } on Object catch (error) {
      Logger.warn('Firebase Analytics user attribution failed: $error');
    }
  }

  static Future<void> trackScreen(String screenName) async {
    final String normalized = screenName.trim();
    if (normalized.isEmpty) {
      return;
    }
    if (screenViewOverride != null) {
      await screenViewOverride!(normalized);
      return;
    }
    if (!_canUseFirebaseAnalytics || Firebase.apps.isEmpty) {
      return;
    }
    try {
      await FirebaseAnalytics.instance.logScreenView(screenName: normalized);
    } on Object catch (error) {
      Logger.warn('Firebase Analytics screen view failed: $error');
    }
  }

  static void track(
    String event, {
    Map<String, Object?> params = const <String, Object?>{},
  }) {
    final bool analyticsEnabled = const IntelligenceService()
        .environmentOnly()
        .flags
        .analyticsEnabled;

    if (!analyticsEnabled) {
      return;
    }

    Logger.log('Analytics', event);
    RuntimeDiagnostics.record('Analytics: $event');

    if (!_canUseFirebaseAnalytics) {
      RuntimeDiagnostics.record(
        'Analytics skipped on unsupported platform: $defaultTargetPlatform',
      );
      return;
    }

    if (Firebase.apps.isEmpty) {
      RuntimeDiagnostics.record(
        'Analytics skipped because Firebase is not initialized.',
      );
      return;
    }

    final Map<String, Object>? analyticsParams = params.isEmpty
        ? null
        : Map<String, Object>.fromEntries(
            params.entries.map(
              (MapEntry<String, Object?> entry) => MapEntry<String, Object>(
                entry.key,
                entry.value?.toString() ?? '',
              ),
            ),
          );

    unawaited(
      FirebaseAnalytics.instance
          .logEvent(name: event, parameters: analyticsParams)
          .catchError((Object error, StackTrace stackTrace) {
            if (error is PlatformException || error is MissingPluginException) {
              Logger.warn(
                'Firebase Analytics unavailable for event "$event": $error',
              );
              RuntimeDiagnostics.record(
                'Firebase Analytics unavailable for event "$event": $error',
              );
              return;
            }

            Logger.warn('Firebase Analytics failed for event "$event": $error');
            RuntimeDiagnostics.record(
              'Firebase Analytics failed for event "$event": $error',
            );
          }),
    );
  }

  static bool get _canUseFirebaseAnalytics {
    if (kIsWeb) {
      return true;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
}
