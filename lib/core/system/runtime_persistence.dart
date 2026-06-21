import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract class RuntimePersistence {
  Future<Map<String, dynamic>?> loadSnapshot();
  Future<void> saveSnapshot(Map<String, dynamic> snapshot);
}

class SharedPrefsRuntimePersistence implements RuntimePersistence {
  SharedPrefsRuntimePersistence({this.key = 'runtime_state_v2'});

  final String key;

  @override
  Future<Map<String, dynamic>?> loadSnapshot() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveSnapshot(Map<String, dynamic> snapshot) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(snapshot));
  }
}
