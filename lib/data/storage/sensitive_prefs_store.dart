import 'dart:convert';

import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SensitiveStorageBackend {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

final class FlutterSensitiveStorageBackend implements SensitiveStorageBackend {
  const FlutterSensitiveStorageBackend(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

// Persists sensitive key/value data in platform secure storage (Keychain/Keystore)
// while retaining known legacy SharedPreferences values as read-only fallbacks.
class SensitivePrefsStore
    implements
        SharedPrefsStore,
        EnumerableSharedPrefsStore,
        CorruptionBackupStore {
  SensitivePrefsStore._({
    SensitiveStorageBackend? backend,
    Future<SharedPreferences> Function()? legacyPreferences,
  }) : _backend =
           backend ??
           const FlutterSensitiveStorageBackend(FlutterSecureStorage()),
       _legacyPreferences = legacyPreferences ?? SharedPreferences.getInstance;

  @visibleForTesting
  SensitivePrefsStore.forTesting({
    required SensitiveStorageBackend backend,
    required Future<SharedPreferences> Function() legacyPreferences,
  }) : this._(backend: backend, legacyPreferences: legacyPreferences);

  static final SensitivePrefsStore instance = SensitivePrefsStore._();
  static const String _storageKey = 'sensitive_preferences_v1';
  static const String _corruptBackupKey =
      'sensitive_preferences_v1_corrupt_backups';
  static const int _maxCorruptBackups = 5;
  static const Set<String> _legacyKeys = <String>{
    'goals_v1',
    'goals_v2',
    'memories_v1',
    'timeline_events_v1',
  };

  final Map<String, String> _values = <String, String>{};
  final Map<String, String> _legacyValues = <String, String>{};
  final SensitiveStorageBackend _backend;
  final Future<SharedPreferences> Function() _legacyPreferences;
  Future<void>? _initializing;
  Future<void> _writeTail = Future<void>.value();
  bool _initialized = false;
  bool _recoveredCorruption = false;
  bool _hasCorruptionBackups = false;

  bool get recoveredCorruption => _recoveredCorruption;

  @override
  bool get hasCorruptionBackups => _hasCorruptionBackups;

  @override
  Future<void> init() {
    if (_initialized) return Future<void>.value();
    return _initializing ??= _initialize().whenComplete(() {
      _initializing = null;
    });
  }

  Future<void> _initialize() async {
    _values.clear();
    _legacyValues.clear();
    _recoveredCorruption = false;
    final String? existingCorruptionBackups = await _backend.read(
      _corruptBackupKey,
    );
    _hasCorruptionBackups =
        existingCorruptionBackups != null &&
        existingCorruptionBackups.trim().isNotEmpty;
    final String? raw = await _backend.read(_storageKey);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic> ||
            decoded.values.any((Object? value) => value is! String)) {
          throw const FormatException(
            'Sensitive preferences payload is not a string map.',
          );
        }
        _values.addAll(decoded.cast<String, String>());
      } on FormatException {
        await _preserveCorruptPayload(raw);
        await _backend.delete(_storageKey);
        _recoveredCorruption = true;
        _hasCorruptionBackups = true;
      }
    }

    final SharedPreferences legacy = await _legacyPreferences();
    for (final String key in _legacyKeys) {
      final String? value = legacy.getString(key);
      if (value == null) continue;
      _legacyValues[key] = value;
    }
    _initialized = true;
  }

  @override
  String? load(String key) => _values[key] ?? _legacyValues[key];

  @override
  Future<void> save(String key, String value) {
    return _enqueueMutation(() async {
      await init();
      await _mutateAndPersist(() => _values[key] = value);
    });
  }

  @override
  Future<void> delete(String key) {
    return _enqueueMutation(() async {
      await init();
      await _mutateAndPersist(() => _values.remove(key));
    });
  }

  @override
  Future<void> clear() {
    return _enqueueMutation(() async {
      final Map<String, String> before = Map<String, String>.of(_values);
      _values.clear();
      try {
        await _backend.delete(_storageKey);
        _initialized = true;
      } on Object {
        _values
          ..clear()
          ..addAll(before);
        rethrow;
      }
      await _backend.delete(_corruptBackupKey);
      _hasCorruptionBackups = false;
    });
  }

  @override
  Future<Set<String>> keys() async {
    await init();
    return Set<String>.unmodifiable(_values.keys);
  }

  @override
  Future<void> clearCorruptionBackups() {
    return _enqueueMutation(() async {
      await _backend.delete(_corruptBackupKey);
      _hasCorruptionBackups = false;
    });
  }

  Future<void> _persist() {
    return _backend.write(_storageKey, jsonEncode(_values));
  }

  Future<void> _preserveCorruptPayload(String raw) async {
    final String? existing = await _backend.read(_corruptBackupKey);
    final List<String> backups = <String>[];
    if (existing != null && existing.trim().isNotEmpty) {
      final Object? decoded = jsonDecode(existing);
      if (decoded is! List<dynamic> ||
          decoded.any((Object? value) => value is! String)) {
        throw const FormatException(
          'Sensitive preferences corruption backup is unreadable.',
        );
      }
      backups.addAll(decoded.cast<String>());
    }
    if (!backups.contains(raw)) {
      if (backups.length >= _maxCorruptBackups) {
        throw StateError('Sensitive preferences corruption backup is full.');
      }
      backups.add(raw);
      await _backend.write(_corruptBackupKey, jsonEncode(backups));
    }
  }

  Future<void> _mutateAndPersist(void Function() mutation) async {
    final Map<String, String> before = Map<String, String>.of(_values);
    mutation();
    try {
      await _persist();
    } on Object {
      _values
        ..clear()
        ..addAll(before);
      rethrow;
    }
  }

  Future<void> _enqueueMutation(Future<void> Function() operation) {
    final Future<void> next = _writeTail.then<void>(
      (_) => operation(),
      onError: (Object _, StackTrace _) => operation(),
    );
    _writeTail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}
