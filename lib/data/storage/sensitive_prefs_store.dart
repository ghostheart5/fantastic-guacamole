import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Persists sensitive key/value data in platform secure storage (Keychain/Keystore)
// and migrates known legacy values previously saved in SharedPreferences.
class SensitivePrefsStore implements SharedPrefsStore {
  SensitivePrefsStore._();

  static final SensitivePrefsStore instance = SensitivePrefsStore._();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const bool _isTestBuild = bool.fromEnvironment('FLUTTER_TEST');
  static const String _storageKey = 'sensitive_preferences_v1';
  static const Set<String> _legacyKeys = <String>{
    'goals_v1',
    'goals_v2',
    'memories_v1',
    'timeline_events_v1',
  };

  final Map<String, String> _values = <String, String>{};
  bool _initialized = false;
  bool _secureStorageAvailable = true;

  @override
  Future<void> init() async {
    if (_initialized) return;

    if (_isTestBuild) {
      _secureStorageAvailable = false;
      _initialized = true;
      return;
    }

    try {
      final String? raw = await _storage
          .read(key: _storageKey)
          .timeout(const Duration(seconds: 3));
      if (raw != null && raw.trim().isNotEmpty) {
        try {
          final Object? decoded = jsonDecode(raw);
          if (decoded is Map) {
            _values.addAll(
              decoded.map(
                (dynamic key, dynamic value) =>
                    MapEntry(key.toString(), value.toString()),
              ),
            );
          }
        } on FormatException {
          await _storage.delete(key: _storageKey);
        }
      }
    } on MissingPluginException catch (error) {
      _secureStorageAvailable = false;
      Logger.warn(
        'SensitivePrefsStore init unavailable; using in-memory fallback for secure storage: $error',
      );
    } on Object catch (error) {
      _secureStorageAvailable = false;
      Logger.warn(
        'SensitivePrefsStore init degraded while reading secure storage: $error',
      );
    }

    try {
      final SharedPreferences legacy = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      bool migrated = false;
      for (final String key in _legacyKeys) {
        if (_values.containsKey(key)) continue;
        final String? value = legacy.getString(key);
        if (value == null) continue;
        _values[key] = value;
        await legacy.remove(key);
        migrated = true;
      }
      if (migrated) {
        await _persist();
      }
    } on Object catch (error) {
      Logger.warn(
        'SensitivePrefsStore init degraded while reading shared preferences: $error',
      );
    }

    _initialized = true;
  }

  @override
  String? load(String key) => _values[key];

  @override
  Future<void> save(String key, String value) async {
    try {
      await init();
      _values[key] = value;
      await _persist();
    } on Object catch (error) {
      Logger.warn('SensitivePrefsStore save degraded: $error');
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await init();
      _values.remove(key);
      await _persist();
    } on Object catch (error) {
      Logger.warn('SensitivePrefsStore delete degraded: $error');
    }
  }

  @override
  Future<void> clear() async {
    _values.clear();
    _initialized = true;
    if (!_secureStorageAvailable) {
      return;
    }
    try {
      await _storage.delete(key: _storageKey);
    } on Object catch (error) {
      Logger.warn('SensitivePrefsStore clear degraded: $error');
    }
  }

  Future<void> _persist() async {
    if (!_secureStorageAvailable) {
      return;
    }
    try {
      await _storage
          .write(key: _storageKey, value: jsonEncode(_values))
          .timeout(const Duration(seconds: 3));
    } on MissingPluginException catch (error) {
      _secureStorageAvailable = false;
      Logger.warn(
        'SensitivePrefsStore persistence unavailable; using in-memory fallback: $error',
      );
    } on Object catch (error) {
      _secureStorageAvailable = false;
      Logger.warn('SensitivePrefsStore persistence degraded: $error');
    }
  }
}
