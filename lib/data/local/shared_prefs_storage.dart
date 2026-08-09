import 'dart:convert';

import 'package:fantastic_guacamole/core/errors/app_exception.dart';
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

  // ------------------------------------------------------------
  // STRING
  // ------------------------------------------------------------

  String? getString(String key) {
    try {
      return prefs.getString(key);
    } on Object catch (error) {
      if (prefs.containsKey(key)) {
        throw StorageException('Stored value for $key is invalid: $error');
      }
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
    } on Object catch (error) {
      if (prefs.containsKey(key)) {
        throw StorageException('Stored value for $key is invalid: $error');
      }
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
    } on Object catch (error) {
      if (prefs.containsKey(key)) {
        throw StorageException('Stored value for $key is invalid: $error');
      }
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
    } on Object catch (error) {
      if (prefs.containsKey(key)) {
        throw StorageException('Stored value for $key is invalid: $error');
      }
      return null;
    }
  }

  double getDoubleOrDefault(String key, double fallback) {
    return getDouble(key) ?? fallback;
  }

  Future<void> setDouble(String key, double value) async {
    await prefs.setDouble(key, value);
  }

  // ------------------------------------------------------------
  // JSON MAP
  // ------------------------------------------------------------

  Map<String, dynamic> getJson(String key) {
    final String? raw = getString(key);
    if (raw == null) return <String, dynamic>{};
    try {
      final Object? decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map(
          (dynamic mapKey, dynamic value) => MapEntry(mapKey.toString(), value),
        );
      }
      throw const FormatException('Stored JSON value is not an object.');
    } on Object catch (error) {
      throw StorageException('Stored JSON for $key is invalid: $error');
    }
  }

  Future<void> setJson(String key, Map<String, dynamic> value) async {
    if (prefs.containsKey(key)) {
      getJson(key);
    }
    await prefs.setString(key, json.encode(value));
  }

  // ------------------------------------------------------------
  // JSON LIST
  // ------------------------------------------------------------

  List<dynamic> getJsonList(String key) {
    final String? raw = getString(key);
    if (raw == null) return <dynamic>[];
    try {
      final Object? decoded = json.decode(raw);
      if (decoded is List<dynamic>) return decoded;
      throw const FormatException('Stored JSON value is not a list.');
    } on Object catch (error) {
      throw StorageException('Stored JSON list for $key is invalid: $error');
    }
  }

  Future<void> setJsonList(String key, List<dynamic> value) async {
    if (prefs.containsKey(key)) {
      getJsonList(key);
    }
    await prefs.setString(key, json.encode(value));
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
