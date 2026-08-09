import 'dart:collection';
import 'dart:convert';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  RemoteConfigService({
    Map<String, Object?> initialValues = const <String, Object?>{},
    this._firebaseRemoteConfig,
    this._refreshOverride,
  }) : _values = Map<String, Object?>.from(initialValues);

  final Map<String, Object?> _values;
  final FirebaseRemoteConfig? _firebaseRemoteConfig;
  final Future<void> Function()? _refreshOverride;
  bool _envSnapshotApplied = false;
  bool _firebaseSnapshotApplied = false;

  static String get _envSnapshot => Env.remoteConfigDefaultsJson;

  Future<void> refresh() async {
    await _applyFirebaseSnapshotIfAvailable();
    await _applyEnvSnapshotIfPresent();
  }

  Future<void> _applyFirebaseSnapshotIfAvailable() async {
    if (_firebaseSnapshotApplied) {
      return;
    }
    if (_refreshOverride == null && !Env.isFirebaseFeatureFlagRuntimeReady) {
      return;
    }
    if (_refreshOverride == null && Firebase.apps.isEmpty) {
      return;
    }

    try {
      if (_refreshOverride != null) {
        await _refreshOverride();
      } else {
        final FirebaseRemoteConfig remoteConfig =
            _firebaseRemoteConfig ?? FirebaseRemoteConfig.instance;
        await remoteConfig.setConfigSettings(
          RemoteConfigSettings(
            fetchTimeout: const Duration(seconds: 8),
            minimumFetchInterval: Env.isProduction
                ? const Duration(hours: 4)
                : const Duration(minutes: 5),
          ),
        );
        await remoteConfig.setDefaults(_values);
        await remoteConfig.fetchAndActivate();
        for (final String key in remoteConfig.getAll().keys) {
          final RemoteConfigValue value = remoteConfig.getValue(key);
          _values[key] = value.asString();
        }
      }
    } on Object catch (error, stackTrace) {
      Logger.errorCategory(
        'Remote Config',
        'Remote Config fetch failed; continuing with defaults or last activated values.',
        error,
        stackTrace,
      );
      RuntimeDiagnostics.record(
        'Remote Config degraded mode: defaults retained.',
      );
    } finally {
      _firebaseSnapshotApplied = true;
    }
  }

  Future<void> _applyEnvSnapshotIfPresent() async {
    if (_envSnapshotApplied || _envSnapshot.trim().isEmpty) {
      return;
    }

    try {
      final Object? decoded = jsonDecode(_envSnapshot);
      if (decoded is! Map) {
        _envSnapshotApplied = true;
        return;
      }

      _values.addAll(
        decoded.map<String, Object?>(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value),
        ),
      );
    } on FormatException {
      // Non-fatal: keep defaults if env snapshot is malformed.
    } finally {
      _envSnapshotApplied = true;
    }
  }

  void applySnapshot(Map<String, Object?> values) {
    _values
      ..clear()
      ..addAll(values);
  }

  Map<String, Object?> snapshot() {
    return UnmodifiableMapView<String, Object?>(_values);
  }

  bool getBool(String key, {bool defaultValue = false}) {
    final Object? value = _values[key];
    if (value is bool) return value;
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return defaultValue;
  }

  String getString(String key, {String defaultValue = ''}) {
    final Object? value = _values[key];
    if (value is String) return value;
    return defaultValue;
  }

  int getInt(String key, {int defaultValue = 0}) {
    final Object? value = _values[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  double getDouble(String key, {double defaultValue = 0}) {
    final Object? value = _values[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }
}
