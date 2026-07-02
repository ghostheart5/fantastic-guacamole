import 'dart:convert';
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

  // ------------------------------------------------------------
  // JSON MAP
  // ------------------------------------------------------------

  Map<String, dynamic> getJson(String key) {
    try {
      final raw = prefs.getString(key);
      if (raw == null) return {};
      final Object? decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map(
          (dynamic mapKey, dynamic mapValue) => MapEntry(mapKey.toString(), mapValue),
        );
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<void> setJson(String key, Map<String, dynamic> value) async {
    await prefs.setString(key, json.encode(value));
  }

  // ------------------------------------------------------------
  // JSON LIST
  // ------------------------------------------------------------

  List<dynamic> getJsonList(String key) {
    try {
      final raw = prefs.getString(key);
      if (raw == null) return [];
      final Object? decoded = json.decode(raw);
      return decoded is List<dynamic> ? decoded : const <dynamic>[];
    } catch (_) {
      return [];
    }
  }

  Future<void> setJsonList(String key, List<dynamic> value) async {
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
