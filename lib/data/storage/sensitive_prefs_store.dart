import 'dart:convert';

import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Persists sensitive key/value data in platform secure storage (Keychain/Keystore)
// and migrates known legacy values previously saved in SharedPreferences.
class SensitivePrefsStore implements SharedPrefsStore {
  SensitivePrefsStore._();

  static final SensitivePrefsStore instance = SensitivePrefsStore._();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _storageKey = 'sensitive_preferences_v1';
  static const Set<String> _legacyKeys = <String>{
    'goals_v1',
    'goals_v2',
    'memories_v1',
    'timeline_events_v1',
  };

  final Map<String, String> _values = <String, String>{};
  bool _initialized = false;

  @override
  Future<void> init() async {
    if (_initialized) return;
    final String? raw = await _storage.read(key: _storageKey);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(raw);
        if (decoded is Map) {
          _values.addAll(
            decoded.map((dynamic key, dynamic value) => MapEntry(key.toString(), value.toString())),
          );
        }
      } on FormatException {
        await _storage.delete(key: _storageKey);
      }
    }

    final SharedPreferences legacy = await SharedPreferences.getInstance();
    bool migrated = false;
    for (final String key in _legacyKeys) {
      if (_values.containsKey(key)) continue;
      final String? value = legacy.getString(key);
      if (value == null) continue;
      _values[key] = value;
      await legacy.remove(key);
      migrated = true;
    }
    if (migrated) await _persist();
    _initialized = true;
  }

  @override
  String? load(String key) => _values[key];

  @override
  Future<void> save(String key, String value) async {
    await init();
    _values[key] = value;
    await _persist();
  }

  @override
  Future<void> delete(String key) async {
    await init();
    _values.remove(key);
    await _persist();
  }

  @override
  Future<void> clear() async {
    _values.clear();
    _initialized = true;
    await _storage.delete(key: _storageKey);
  }

  Future<void> _persist() {
    return _storage.write(key: _storageKey, value: jsonEncode(_values));
  }
}
