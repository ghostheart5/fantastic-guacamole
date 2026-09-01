import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class TelemetryConsent {
  const TelemetryConsent({this.analytics = false, this.crashReporting = false});

  final bool analytics;
  final bool crashReporting;

  TelemetryConsent copyWith({bool? analytics, bool? crashReporting}) {
    return TelemetryConsent(
      analytics: analytics ?? this.analytics,
      crashReporting: crashReporting ?? this.crashReporting,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TelemetryConsent &&
        other.analytics == analytics &&
        other.crashReporting == crashReporting;
  }

  @override
  int get hashCode => Object.hash(analytics, crashReporting);
}

typedef TelemetryRuntimeConfigurer =
    Future<void> Function(TelemetryConsent consent);

/// Stores a person's telemetry choices locally under a one-way account scope.
/// Collection still needs both this consent and the reviewed build capability.
class TelemetryConsentStore {
  TelemetryConsentStore({
    Future<SharedPreferences> Function()? preferences,
    TelemetryRuntimeConfigurer? configureRuntime,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _configureRuntime = configureRuntime ?? _configureFirebaseRuntime;

  static const String _keyPrefix = 'telemetry_consent_v1';

  final Future<SharedPreferences> Function() _preferences;
  final TelemetryRuntimeConfigurer _configureRuntime;

  static String storageKeyForAccount(String accountId) {
    final String digest = sha256
        .convert(utf8.encode(accountId.trim()))
        .toString();
    return '$_keyPrefix.$digest';
  }

  Future<TelemetryConsent> load(String accountId) async {
    if (accountId.trim().isEmpty) {
      return const TelemetryConsent();
    }
    final SharedPreferences preferences = await _preferences();
    final String key = storageKeyForAccount(accountId);
    return TelemetryConsent(
      analytics: preferences.getBool('$key.analytics') ?? false,
      crashReporting: preferences.getBool('$key.crash_reporting') ?? false,
    );
  }

  Future<TelemetryConsent> save({
    required String accountId,
    required TelemetryConsent consent,
  }) async {
    if (accountId.trim().isEmpty) {
      return const TelemetryConsent();
    }
    final SharedPreferences preferences = await _preferences();
    final String key = storageKeyForAccount(accountId);
    await preferences.setBool('$key.analytics', consent.analytics);
    await preferences.setBool('$key.crash_reporting', consent.crashReporting);
    await _configureRuntime(consent);
    return consent;
  }

  Future<void> applyForAccount(String? accountId) async {
    final TelemetryConsent consent = accountId == null
        ? const TelemetryConsent()
        : await load(accountId);
    await _configureRuntime(consent);
  }

  static bool analyticsCollectionEnabled(TelemetryConsent consent) {
    return Env.enableAnalytics && consent.analytics;
  }

  static bool crashCollectionEnabled(TelemetryConsent consent) {
    return Env.enableCrashReporting && consent.crashReporting;
  }

  static Future<void> _configureFirebaseRuntime(
    TelemetryConsent consent,
  ) async {
    if (kIsWeb || Firebase.apps.isEmpty) {
      return;
    }
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
      analyticsCollectionEnabled(consent),
    );
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
          crashCollectionEnabled(consent),
        );
        break;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        break;
    }
  }
}
