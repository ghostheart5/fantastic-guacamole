import 'dart:convert';

import 'package:flutter/services.dart';

class AssetLoader {
  static Future<List<dynamic>> loadJsonList(String path) async {
    final data = await rootBundle.loadString(path);
    final Object? decoded = json.decode(data);
    return decoded is List<dynamic> ? decoded : const <dynamic>[];
  }

  static Future<Map<String, dynamic>> loadJson(String path) async {
    final data = await rootBundle.loadString(path);
    final Object? decoded = json.decode(data);
    return decoded is Map<String, dynamic>
        ? decoded
        : const <String, dynamic>{};
  }
}
