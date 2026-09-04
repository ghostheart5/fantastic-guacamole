import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecureStoreBackend {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
  Future<void> deleteAll();

  Future<Map<String, String>> readAll() async => const <String, String>{};
}

class RealSecureStoreBackend implements SecureStoreBackend {
  RealSecureStoreBackend({required this._storage});

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete({required String key}) {
    return _storage.delete(key: key);
  }

  @override
  Future<void> deleteAll() {
    return _storage.deleteAll();
  }

  @override
  Future<Map<String, String>> readAll() {
    return _storage.readAll();
  }
}

class InMemorySecureStoreBackend implements SecureStoreBackend {
  final Map<String, String> _memory = <String, String>{};

  @override
  Future<String?> read({required String key}) async {
    return _memory[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _memory[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _memory.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _memory.clear();
  }

  @override
  Future<Map<String, String>> readAll() async {
    return Map<String, String>.unmodifiable(_memory);
  }
}

class SecureStore {
  static const String _legacyClearMarker =
      '__chronospark_internal_legacy_fallback_cleared__';
  static const String _legacyDeleteMarkerPrefix =
      '__chronospark_internal_legacy_fallback_deleted__.';

  SecureStore({required this._backend})
    : _accountScope = null,
      _legacyOwnership = LegacyScopeOwnership.ambiguous;

  SecureStore._accountScoped({
    required this._backend,
    required AccountStorageScope scope,
    required this._legacyOwnership,
  }) : _accountScope = scope;

  final SecureStoreBackend _backend;
  final AccountStorageScope? _accountScope;
  final LegacyScopeOwnership _legacyOwnership;

  /// Returns a view that can access only this account's V2 keys.
  ///
  /// Legacy values are read-only fallbacks and only when ownership has already
  /// been proven by the authentication boundary. Reads never copy or delete a
  /// legacy value, and every mutation targets the account-scoped key.
  SecureStore forAccount(
    AccountStorageScope scope, {
    LegacyScopeOwnership legacyOwnership = LegacyScopeOwnership.ambiguous,
  }) => SecureStore._accountScoped(
    backend: _backend,
    scope: scope,
    legacyOwnership: legacyOwnership,
  );

  Future<String?> readString(String key) async {
    final String storageKey = _storageKey(key);
    final String? scoped = await _backend.read(key: storageKey);
    if (scoped != null ||
        _accountScope == null ||
        _legacyOwnership != LegacyScopeOwnership.provenOwned) {
      return scoped;
    }
    if (await _legacyFallbackIsSuppressed(key)) {
      return null;
    }
    return _backend.read(key: key);
  }

  Future<void> writeString(String key, String value) async {
    await _backend.write(key: _storageKey(key), value: value);
    final AccountStorageScope? scope = _accountScope;
    if (scope != null) {
      await _backend.delete(key: _storageKey(_legacyDeleteMarkerFor(key)));
    }
  }

  Future<void> delete(String key) async {
    final AccountStorageScope? scope = _accountScope;
    if (scope != null) {
      // Suppress the legacy fallback before removing the scoped value so a
      // partially failed delete cannot expose preserved legacy account data.
      await _backend.write(
        key: _storageKey(_legacyDeleteMarkerFor(key)),
        value: 'true',
      );
    }
    await _backend.delete(key: _storageKey(key));
  }

  Future<bool?> readBool(String key) async {
    final String? value = await readString(key);
    if (value == null) {
      return null;
    }
    if (value == 'true') {
      return true;
    }
    if (value == 'false') {
      return false;
    }
    return null;
  }

  Future<void> writeBool(String key, bool value) {
    return writeString(key, value ? 'true' : 'false');
  }

  Future<double?> readDouble(String key) async {
    final String? value = await readString(key);
    if (value == null) {
      return null;
    }
    return double.tryParse(value);
  }

  Future<void> writeDouble(String key, double value) {
    return writeString(key, value.toString());
  }

  Future<void> deleteAll() async {
    final AccountStorageScope? scope = _accountScope;
    if (scope == null) {
      await _backend.deleteAll();
      return;
    }
    final String clearMarkerStorageKey = _storageKey(_legacyClearMarker);
    await _backend.write(key: clearMarkerStorageKey, value: 'true');
    final String suffix = _scopeSuffix(scope);
    final Map<String, String> values = await _backend.readAll();
    for (final String key in values.keys.where(
      (String key) => key.endsWith(suffix) && key != clearMarkerStorageKey,
    )) {
      await _backend.delete(key: key);
    }
  }

  Future<Map<String, String>> readAll() async {
    final Map<String, String> values = await _backend.readAll();
    final AccountStorageScope? scope = _accountScope;
    if (scope == null) {
      return values;
    }
    final String suffix = _scopeSuffix(scope);
    return Map<String, String>.unmodifiable(<String, String>{
      for (final MapEntry<String, String> entry in values.entries)
        if (entry.key.endsWith(suffix) && !_isInternalStorageKey(entry.key))
          entry.key.substring(0, entry.key.length - suffix.length): entry.value,
    });
  }

  Future<bool> _legacyFallbackIsSuppressed(String key) async {
    if (await _backend.read(key: _storageKey(_legacyClearMarker)) != null) {
      return true;
    }
    return await _backend.read(key: _storageKey(_legacyDeleteMarkerFor(key))) !=
        null;
  }

  String _legacyDeleteMarkerFor(String key) {
    return '$_legacyDeleteMarkerPrefix${base64UrlEncode(utf8.encode(key))}';
  }

  bool _isInternalStorageKey(String storageKey) {
    return storageKey.startsWith(_legacyDeleteMarkerPrefix) ||
        storageKey.startsWith(_legacyClearMarker);
  }

  String _storageKey(String key) {
    final AccountStorageScope? scope = _accountScope;
    if (scope == null) {
      return key;
    }
    final AccountStorageNamespace? namespace = scope.namespace;
    if (!scope.isWritable || namespace == null) {
      throw StateError('Account-owned secure storage is not writable.');
    }
    return namespace.scopedKey(key);
  }

  String _scopeSuffix(AccountStorageScope scope) {
    final String? namespace = scope.v2Namespace;
    if (!scope.isWritable || namespace == null) {
      throw StateError('Account-owned secure storage is not writable.');
    }
    return '.$namespace';
  }
}
