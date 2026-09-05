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
  const TelemetryConsent({
    this.analytics = false,
    this.crashReporting = false,
    this.consentVersion = 0,
    this.updatedAtUtc,
  });

  static const int currentConsentVersion = 1;

  final bool analytics;
  final bool crashReporting;
  final int consentVersion;
  final DateTime? updatedAtUtc;

  bool get isCurrent =>
      consentVersion == currentConsentVersion &&
      updatedAtUtc != null &&
      updatedAtUtc!.isUtc;

  TelemetryConsent copyWith({
    bool? analytics,
    bool? crashReporting,
    int? consentVersion,
    DateTime? updatedAtUtc,
  }) {
    return TelemetryConsent(
      analytics: analytics ?? this.analytics,
      crashReporting: crashReporting ?? this.crashReporting,
      consentVersion: consentVersion ?? this.consentVersion,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TelemetryConsent &&
        other.analytics == analytics &&
        other.crashReporting == crashReporting &&
        other.consentVersion == consentVersion &&
        other.updatedAtUtc == updatedAtUtc;
  }

  @override
  int get hashCode =>
      Object.hash(analytics, crashReporting, consentVersion, updatedAtUtc);
}

typedef TelemetryRuntimeConfigurer =
    Future<void> Function(TelemetryConsent consent);

/// Serializes runtime collection changes across rapid account transitions.
///
/// Firebase exposes process-wide collection switches, so concurrent consent
/// applications could otherwise finish out of order and leave a departing
/// account's choice active for the next person on the device.
class TelemetryConsentAccountTransitionCoordinator {
  TelemetryConsentAccountTransitionCoordinator(this._store);

  final TelemetryConsentStore _store;
  Future<void> _tail = Future<void>.value();

  Future<void> applyForAccount(String? accountId) {
    final Future<void> scheduled = _tail.then(
      (_) => _store.applyForAccount(accountId),
    );
    _tail = scheduled.then<void>((_) {}, onError: (_, _) {});
    return scheduled;
  }
}

/// Stores a person's telemetry choices locally under a one-way account scope.
/// Collection still needs both this consent and the reviewed build capability.
class TelemetryConsentStore {
  TelemetryConsentStore({
    Future<SharedPreferences> Function()? preferences,
    TelemetryRuntimeConfigurer? configureRuntime,
    DateTime Function()? now,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _configureRuntime = configureRuntime ?? _configureFirebaseRuntime,
       _now = now ?? DateTime.now;

  static const String _keyPrefix = 'telemetry_consent_v1';
  static const TelemetryConsent _off = TelemetryConsent();
  static TelemetryConsent _activeRuntimeConsent = _off;

  final Future<SharedPreferences> Function() _preferences;
  final TelemetryRuntimeConfigurer _configureRuntime;
  final DateTime Function() _now;

  static bool get analyticsDispatchAllowed =>
      analyticsCollectionEnabled(_activeRuntimeConsent);

  static bool get crashDispatchAllowed =>
      crashCollectionEnabled(_activeRuntimeConsent);

  @visibleForTesting
  static void resetRuntimeGateForTesting() {
    _activeRuntimeConsent = _off;
  }

  static String storageKeyForAccount(String accountId) {
    final String digest = sha256
        .convert(utf8.encode(accountId.trim()))
        .toString();
    return '$_keyPrefix.$digest';
  }

  Future<TelemetryConsent> load(String accountId) async {
    if (accountId.trim().isEmpty) {
      return _off;
    }
    final SharedPreferences preferences = await _preferences();
    final String key = storageKeyForAccount(accountId);
    return _decode(_snapshot(preferences, key));
  }

  Future<TelemetryConsent> save({
    required String accountId,
    required TelemetryConsent consent,
  }) async {
    if (accountId.trim().isEmpty) {
      await _applyFailClosed(_off);
      return _off;
    }
    final SharedPreferences preferences = await _preferences();
    final String key = storageKeyForAccount(accountId);
    final _StoredConsentSnapshot previous = _snapshot(preferences, key);
    final TelemetryConsent next = TelemetryConsent(
      analytics: consent.analytics,
      crashReporting: consent.crashReporting,
      consentVersion: TelemetryConsent.currentConsentVersion,
      updatedAtUtc: _now().toUtc(),
    );

    // Close the process-wide dispatch gate before persistence or Firebase can
    // change. No event can escape while a consent transition is incomplete.
    await _applyFailClosed(_off);
    try {
      await _write(preferences, key, next);
      if (_hasOptIn(next)) {
        await _configureRuntime(next);
      }
      _activeRuntimeConsent = next;
      return next;
    } on Object {
      // A partially written record must never turn into implicit consent on
      // restart. Restore the prior bytes, keep runtime collection disabled,
      // and surface the failure to the caller.
      try {
        await _restore(preferences, key, previous);
      } on Object {
        await _removeRecord(preferences, key);
      }
      await _applyFailClosed(_off);
      rethrow;
    }
  }

  Future<void> applyForAccount(String? accountId) async {
    await _applyFailClosed(_off);
    final TelemetryConsent consent = accountId == null
        ? _off
        : await load(accountId);
    if (_hasOptIn(consent)) {
      try {
        await _configureRuntime(consent);
      } on Object {
        await _applyFailClosed(_off);
        rethrow;
      }
    }
    _activeRuntimeConsent = consent;
  }

  static bool analyticsCollectionEnabled(TelemetryConsent consent) {
    return Env.cloudServicesEnabled &&
        Env.enableAnalytics &&
        consent.isCurrent &&
        consent.analytics;
  }

  static bool crashCollectionEnabled(TelemetryConsent consent) {
    return Env.cloudServicesEnabled &&
        Env.enableCrashReporting &&
        consent.isCurrent &&
        consent.crashReporting;
  }

  bool _hasOptIn(TelemetryConsent consent) =>
      consent.isCurrent && (consent.analytics || consent.crashReporting);

  Future<void> _applyFailClosed(TelemetryConsent consent) async {
    _activeRuntimeConsent = _off;
    try {
      await _configureRuntime(consent);
    } on Object {
      _activeRuntimeConsent = _off;
      rethrow;
    }
  }

  _StoredConsentSnapshot _snapshot(SharedPreferences preferences, String key) {
    try {
      return (
        analytics: preferences.getBool('$key.analytics'),
        crashReporting: preferences.getBool('$key.crash_reporting'),
        consentVersion: preferences.getInt('$key.consent_version'),
        updatedAtUtc: preferences.getString('$key.updated_at_utc'),
      );
    } on Object {
      return const (
        analytics: null,
        crashReporting: null,
        consentVersion: null,
        updatedAtUtc: null,
      );
    }
  }

  TelemetryConsent _decode(_StoredConsentSnapshot snapshot) {
    final DateTime? updatedAt = DateTime.tryParse(snapshot.updatedAtUtc ?? '');
    if (snapshot.consentVersion != TelemetryConsent.currentConsentVersion ||
        updatedAt == null) {
      return _off;
    }
    return TelemetryConsent(
      analytics: snapshot.analytics ?? false,
      crashReporting: snapshot.crashReporting ?? false,
      consentVersion: snapshot.consentVersion!,
      updatedAtUtc: updatedAt.toUtc(),
    );
  }

  Future<void> _write(
    SharedPreferences preferences,
    String key,
    TelemetryConsent consent,
  ) async {
    await _requireWrite(
      preferences.setBool('$key.analytics', consent.analytics),
      '$key.analytics',
    );
    await _requireWrite(
      preferences.setBool('$key.crash_reporting', consent.crashReporting),
      '$key.crash_reporting',
    );
    await _requireWrite(
      preferences.setInt('$key.consent_version', consent.consentVersion),
      '$key.consent_version',
    );
    await _requireWrite(
      preferences.setString(
        '$key.updated_at_utc',
        consent.updatedAtUtc!.toIso8601String(),
      ),
      '$key.updated_at_utc',
    );
  }

  Future<void> _restore(
    SharedPreferences preferences,
    String key,
    _StoredConsentSnapshot snapshot,
  ) async {
    await _writeNullable(preferences, '$key.analytics', snapshot.analytics);
    await _writeNullable(
      preferences,
      '$key.crash_reporting',
      snapshot.crashReporting,
    );
    await _writeNullable(
      preferences,
      '$key.consent_version',
      snapshot.consentVersion,
    );
    await _writeNullable(
      preferences,
      '$key.updated_at_utc',
      snapshot.updatedAtUtc,
    );
  }

  Future<void> _writeNullable(
    SharedPreferences preferences,
    String key,
    Object? value,
  ) async {
    final Future<bool> result = switch (value) {
      bool value => preferences.setBool(key, value),
      int value => preferences.setInt(key, value),
      String value => preferences.setString(key, value),
      _ => preferences.remove(key),
    };
    await _requireWrite(result, key);
  }

  Future<void> _removeRecord(SharedPreferences preferences, String key) async {
    for (final String suffix in <String>[
      'analytics',
      'crash_reporting',
      'consent_version',
      'updated_at_utc',
    ]) {
      await preferences.remove('$key.$suffix');
    }
  }

  Future<void> _requireWrite(Future<bool> write, String key) async {
    if (!await write) {
      throw StateError('Telemetry consent storage rejected $key.');
    }
  }

  static Future<void> _configureFirebaseRuntime(
    TelemetryConsent consent,
  ) async {
    if (!Env.cloudServicesEnabled || kIsWeb || Firebase.apps.isEmpty) {
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

typedef _StoredConsentSnapshot = ({
  bool? analytics,
  bool? crashReporting,
  int? consentVersion,
  String? updatedAtUtc,
});
