import 'dart:convert';

/// Safe JSON helpers for ChronoSpark.
/// Prevents crashes from malformed or unexpected JSON structures.
class JsonUtils {
  /// Safely decodes a JSON string into a Map.
  /// Returns an empty map on failure.
  static Map<String, dynamic> decodeMap(String source) {
    try {
      final decoded = json.decode(source);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  /// Safely decodes a JSON string into a List.
  /// Returns an empty list on failure.
  static List<dynamic> decodeList(String source) {
    try {
      final decoded = json.decode(source);
      if (decoded is List) {
        return decoded;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Safely encodes any object to JSON.
  /// Returns 'null' on failure.
  static String encode(Object? value) {
    try {
      return json.encode(value);
    } catch (_) {
      return 'null';
    }
  }

  /// Safely gets a string from a JSON map.
  static String getString(
    Map<String, dynamic> json,
    String key, {
    String fallback = '',
  }) {
    final value = json[key];
    return value is String ? value : fallback;
  }

  /// Safely gets a number from a JSON map.
  static num getNum(Map<String, dynamic> json, String key, {num fallback = 0}) {
    final value = json[key];
    return value is num ? value : fallback;
  }

  /// Safely gets an integer from a JSON map.
  static int getInt(Map<String, dynamic> json, String key, {int fallback = 0}) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  /// Safely gets a double from a JSON map.
  static double getDouble(
    Map<String, dynamic> json,
    String key, {
    double fallback = 0.0,
  }) {
    final value = json[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return fallback;
  }

  /// Safely gets a boolean from a JSON map.
  static bool getBool(
    Map<String, dynamic> json,
    String key, {
    bool fallback = false,
  }) {
    final value = json[key];
    return value is bool ? value : fallback;
  }

  /// Safely gets a nested map.
  static Map<String, dynamic> getMap(
    Map<String, dynamic> json,
    String key, {
    Map<String, dynamic> fallback = const {},
  }) {
    final value = json[key];
    return value is Map<String, dynamic> ? value : fallback;
  }

  /// Safely gets a list.
  static List<dynamic> getList(
    Map<String, dynamic> json,
    String key, {
    List<dynamic> fallback = const [],
  }) {
    final value = json[key];
    return value is List ? value : fallback;
  }

  /// Safely attempts to decode JSON, returning null on failure.
  static dynamic tryDecode(String? source) {
    if (source == null || source.trim().isEmpty) return null;
    try {
      return json.decode(source);
    } catch (_) {
      return null;
    }
  }
}
