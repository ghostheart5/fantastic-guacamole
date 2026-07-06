import 'dart:collection';
import 'dart:convert';

class RemoteConfigService {
  RemoteConfigService({
    Map<String, Object?> initialValues = const <String, Object?>{},
  }) : _values = Map<String, Object?>.from(initialValues);

  final Map<String, Object?> _values;
  bool _envSnapshotApplied = false;

  static const String _envSnapshot = String.fromEnvironment(
    'CHRONOSPARK_REMOTE_CONFIG_JSON',
    defaultValue: '',
  );

  Future<void> refresh() async {
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
