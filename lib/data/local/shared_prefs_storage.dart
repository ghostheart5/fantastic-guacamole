import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ChronoSpark SharedPrefsStorage
/// A typed, safe wrapper around SharedPreferences.
/// Provides:
/// - safe read/write
/// - typed access
/// - JSON helpers
/// - existence checks
/// - non-null guarantees
class SharedPrefsStorage {
  final SharedPreferences prefs;

  SharedPrefsStorage(this.prefs);

  Object? get(String key) => prefs.get(key);

  // ------------------------------------------------------------
  // STRING
  // ------------------------------------------------------------

  String? getString(String key) {
    try {
      return prefs.getString(key);
    } catch (_) {
      return null;
    }
  }

  String getStringOrDefault(String key, String fallback) {
    return getString(key) ?? fallback;
  }

  Future<void> setString(String key, String value) async {
    await prefs.setString(key, value);
  }

  // ------------------------------------------------------------
  // BOOL
  // ------------------------------------------------------------

  bool? getBool(String key) {
    try {
      return prefs.getBool(key);
    } catch (_) {
      return null;
    }
  }

  bool getBoolOrDefault(String key, bool fallback) {
    return getBool(key) ?? fallback;
  }

  Future<void> setBool(String key, bool value) async {
    await prefs.setBool(key, value);
  }

  // ------------------------------------------------------------
  // INT
  // ------------------------------------------------------------

  int? getInt(String key) {
    try {
      return prefs.getInt(key);
    } catch (_) {
      return null;
    }
  }

  int getIntOrDefault(String key, int fallback) {
    return getInt(key) ?? fallback;
  }

  Future<void> setInt(String key, int value) async {
    await prefs.setInt(key, value);
  }

  // ------------------------------------------------------------
  // DOUBLE
  // ------------------------------------------------------------

  double? getDouble(String key) {
    try {
      return prefs.getDouble(key);
    } catch (_) {
      return null;
    }
  }

  double getDoubleOrDefault(String key, double fallback) {
    return getDouble(key) ?? fallback;
  }

  Future<void> setDouble(String key, double value) async {
    await prefs.setDouble(key, value);
  }

  Future<void> setStringList(String key, List<String> value) async {
    await prefs.setStringList(key, value);
  }

  // ------------------------------------------------------------
  // JSON MAP
  // ------------------------------------------------------------

  Map<String, dynamic> getJson(String key) {
    try {
      final raw = getString(key);
      if (raw == null) return {};
      final Object? decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value),
        );
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<void> setJson(String key, Map<String, dynamic> value) async {
    await setString(key, json.encode(value));
  }

  // ------------------------------------------------------------
  // JSON LIST
  // ------------------------------------------------------------

  List<dynamic> getJsonList(String key) {
    try {
      final raw = getString(key);
      if (raw == null) return [];
      final Object? decoded = json.decode(raw);
      return decoded is List<dynamic> ? decoded : const <dynamic>[];
    } catch (_) {
      return [];
    }
  }

  Future<void> setJsonList(String key, List<dynamic> value) async {
    await setString(key, json.encode(value));
  }

  // ------------------------------------------------------------
  // EXISTENCE + REMOVE + CLEAR
  // ------------------------------------------------------------

  bool contains(String key) {
    try {
      return prefs.containsKey(key);
    } catch (_) {
      return false;
    }
  }

  Future<void> remove(String key) async {
    await prefs.remove(key);
  }

  Future<void> clear() async {
    await prefs.clear();
  }
}

/// Typed account-scoped view used by backup and local-test-cloud services.
///
/// Legacy reads are allowed only for the proven legacy owner. Deletion and
/// clearing preserve legacy values and leave account-local suppression markers
/// so removed values cannot reappear through fallback.
final class AccountScopedSharedPrefsStorage extends SharedPrefsStorage {
  AccountScopedSharedPrefsStorage({
    required SharedPrefsStorage delegate,
    required this.scope,
    this.legacyOwnership = LegacyScopeOwnership.ambiguous,
  }) : super(delegate.prefs);

  static const String _legacyClearMarker =
      '__chronospark_internal_typed_legacy_fallback_cleared__';
  static const String _legacyDeleteMarkerPrefix =
      '__chronospark_internal_typed_legacy_fallback_deleted__.';

  final AccountStorageScope scope;
  final LegacyScopeOwnership legacyOwnership;

  @override
  Object? get(String key) => _read<Object>(key, prefs.get);

  @override
  String? getString(String key) => _read<String>(key, prefs.getString);

  @override
  bool? getBool(String key) => _read<bool>(key, prefs.getBool);

  @override
  int? getInt(String key) => _read<int>(key, prefs.getInt);

  @override
  double? getDouble(String key) => _read<double>(key, prefs.getDouble);

  @override
  Future<void> setString(String key, String value) =>
      _write(key, () => prefs.setString(_storageKey(key), value));

  @override
  Future<void> setBool(String key, bool value) =>
      _write(key, () => prefs.setBool(_storageKey(key), value));

  @override
  Future<void> setInt(String key, int value) =>
      _write(key, () => prefs.setInt(_storageKey(key), value));

  @override
  Future<void> setDouble(String key, double value) =>
      _write(key, () => prefs.setDouble(_storageKey(key), value));

  @override
  Future<void> setStringList(String key, List<String> value) =>
      _write(key, () => prefs.setStringList(_storageKey(key), value));

  @override
  bool contains(String key) => get(key) != null;

  @override
  Future<void> remove(String key) async {
    await prefs.setBool(_storageKey(_deleteMarkerFor(key)), true);
    await prefs.remove(_storageKey(key));
  }

  @override
  Future<void> clear() async {
    final String clearMarker = _storageKey(_legacyClearMarker);
    await prefs.setBool(clearMarker, true);
    final String suffix = _scopeSuffix();
    for (final String key in prefs.getKeys().where(
      (String key) => key.endsWith(suffix) && key != clearMarker,
    )) {
      await prefs.remove(key);
    }
  }

  T? _read<T>(String key, T? Function(String key) reader) {
    final T? scoped = reader(_storageKey(key));
    if (scoped != null || legacyOwnership != LegacyScopeOwnership.provenOwned) {
      return scoped;
    }
    if (prefs.containsKey(_storageKey(_legacyClearMarker)) ||
        prefs.containsKey(_storageKey(_deleteMarkerFor(key)))) {
      return null;
    }
    return reader(key);
  }

  Future<void> _write(String key, Future<bool> Function() persist) async {
    await persist();
    await prefs.remove(_storageKey(_deleteMarkerFor(key)));
  }

  String _storageKey(String key) {
    final AccountStorageNamespace? namespace = scope.namespace;
    if (!scope.isWritable || namespace == null) {
      throw StateError('Account-owned typed preferences are not writable.');
    }
    return namespace.scopedKey(key);
  }

  String _scopeSuffix() {
    final String? namespace = scope.v2Namespace;
    if (!scope.isWritable || namespace == null) {
      throw StateError('Account-owned typed preferences are not writable.');
    }
    return '.$namespace';
  }

  String _deleteMarkerFor(String key) {
    return '$_legacyDeleteMarkerPrefix${base64UrlEncode(utf8.encode(key))}';
  }
}
