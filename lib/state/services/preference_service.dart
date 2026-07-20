import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';

class PreferenceService {
  static const String _kOnboardingComplete = 'onboarding_complete';
  static const String _kOnboardingContentVersion = 'onboarding_content_version';
  static const String _kLastOpenedTab = 'last_opened_tab';
  static const String _kUserPreferences = 'user_preferences_json';

  Future<void> setOnboardingComplete(bool isComplete) async {
    await SharedPrefsService.save(_kOnboardingComplete, isComplete.toString());
  }

  bool getOnboardingComplete() {
    return SharedPrefsService.load(_kOnboardingComplete) == 'true';
  }

  Future<void> setOnboardingContentVersion(int version) async {
    await SharedPrefsService.save(
      _kOnboardingContentVersion,
      version.toString(),
    );
  }

  int? getOnboardingContentVersion() {
    final String? raw = SharedPrefsService.load(_kOnboardingContentVersion);
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> setLastOpenedTab(int tabIndex) async {
    await SharedPrefsService.save(_kLastOpenedTab, tabIndex.toString());
  }

  int? getLastOpenedTab() {
    final String? raw = SharedPrefsService.load(_kLastOpenedTab);
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> setUserPreference(String key, Object value) async {
    final Map<String, dynamic> prefs = getUserPreferences();
    prefs[key] = value;
    await SharedPrefsService.save(_kUserPreferences, jsonEncode(prefs));
  }

  Map<String, dynamic> getUserPreferences() {
    final String? raw = SharedPrefsService.load(_kUserPreferences);
    if (raw == null || raw.trim().isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value),
        );
      }
      Logger.warn('User preferences payload is not a JSON object and will be ignored.');
    } on FormatException catch (error) {
      Logger.warn('User preferences payload is corrupted and will be ignored: $error');
    }
    return <String, dynamic>{};
  }
}
