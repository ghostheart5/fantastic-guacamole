import 'dart:convert';

import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';

class PreferenceService {
  PreferenceService({SharedPrefsStore? deviceStore, this.accountStore})
    : _deviceStore = deviceStore ?? const SharedPrefsStoreAdapter();

  final SharedPrefsStore _deviceStore;
  final SharedPrefsStore? accountStore;

  static const String _kOnboardingComplete = 'onboarding_complete';
  static const String _kOnboardingContentVersion = 'onboarding_content_version';
  static const String _kLastOpenedTab = 'last_opened_tab';
  static const String _kUserPreferences = 'user_preferences_json';

  Future<void> setOnboardingComplete(bool isComplete) async {
    await _deviceStore.save(_kOnboardingComplete, isComplete.toString());
  }

  bool getOnboardingComplete() {
    return _deviceStore.load(_kOnboardingComplete) == 'true';
  }

  Future<void> setOnboardingContentVersion(int version) async {
    await _deviceStore.save(_kOnboardingContentVersion, version.toString());
  }

  int? getOnboardingContentVersion() {
    final String? raw = _deviceStore.load(_kOnboardingContentVersion);
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> setLastOpenedTab(int tabIndex) async {
    await _requireAccountStore().save(_kLastOpenedTab, tabIndex.toString());
  }

  int? getLastOpenedTab() {
    final String? raw = _requireAccountStore().load(_kLastOpenedTab);
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> setUserPreference(String key, Object value) async {
    final Map<String, dynamic> prefs = getUserPreferences();
    prefs[key] = value;
    await _requireAccountStore().save(_kUserPreferences, jsonEncode(prefs));
  }

  Map<String, dynamic> getUserPreferences() {
    final String? raw = _requireAccountStore().load(_kUserPreferences);
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
    } catch (_) {
      // Fall through to empty map on invalid payloads.
    }
    return <String, dynamic>{};
  }

  SharedPrefsStore _requireAccountStore() {
    return accountStore ??
        (throw StateError('Account-owned preferences require a safe scope.'));
  }
}
