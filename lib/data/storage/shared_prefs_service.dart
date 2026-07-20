import 'dart:async';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class SharedPrefsStore {
  Future<void> init();
  Future<void> save(String key, String value);
  String? load(String key);
  Future<void> delete(String key);
  Future<void> clear();
}

class SharedPrefsStoreAdapter implements SharedPrefsStore {
  const SharedPrefsStoreAdapter();

  @override
  Future<void> init() {
    return SharedPrefsService.init();
  }

  @override
  Future<void> save(String key, String value) {
    return SharedPrefsService.save(key, value);
  }

  @override
  String? load(String key) {
    return SharedPrefsService.load(key);
  }

  @override
  Future<void> delete(String key) {
    return SharedPrefsService.delete(key);
  }

  @override
  Future<void> clear() {
    return SharedPrefsService.clear();
  }
}

class SharedPrefsService {
  static SharedPreferences? _prefs;
  static Future<void>? _initFuture;
  static Object? _initError;
  static bool _didLogInitialized = false;
  static const List<String> _sensitiveKeyMarkers = <String>[
    'token',
    'secret',
    'password',
    'credential',
    'auth_session',
  ];

  static Future<void> init() async {
    final SharedPreferences? existing = _prefs;
    if (existing != null) {
      return;
    }

    final Future<void>? inFlight = _initFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    _initFuture = () async {
      try {
        _prefs ??= await SharedPreferences.getInstance();
        _initError = null;
        if (!_didLogInitialized) {
          Logger.log('SharedPrefsService', 'Initialized');
          _didLogInitialized = true;
        }
      } on Object catch (error) {
        _initError = error;
        Logger.error(
          'SharedPrefsService initialization failed. Using degraded storage mode.',
          error,
        );
      } finally {
        _initFuture = null;
      }
    }();

    await _initFuture;
  }

  static Future<void> save(String key, String value) async {
    await init();
    if (_looksSensitiveKey(key)) {
      Logger.warn(
        'SharedPrefsService: Blocked write to SharedPreferences for sensitive key "$key".',
      );
      return;
    }
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) {
      if (_initError != null) {
        Logger.warn(
          'SharedPrefsService save skipped due to initialization failure: $_initError',
        );
      }
      throw StateError('SharedPrefsService storage is unavailable for save($key).');
    }
    await saveStringWithPrefs(prefs, key, value);
  }

  static Future<void> saveBool(String key, bool value) async {
    await init();
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) {
      throw StateError('SharedPrefsService storage is unavailable for saveBool($key).');
    }
    await saveBoolWithPrefs(prefs, key, value);
  }

  static Future<void> saveInt(String key, int value) async {
    await init();
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) {
      throw StateError('SharedPrefsService storage is unavailable for saveInt($key).');
    }
    await saveIntWithPrefs(prefs, key, value);
  }

  static String? load(String key) {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) {
      if (_initFuture == null) {
        unawaited(init());
      }
      return null;
    }
    return prefs.getString(key);
  }

  static Future<void> delete(String key) async {
    await init();
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) {
      if (_initError != null) {
        Logger.warn(
          'SharedPrefsService delete skipped due to initialization failure: $_initError',
        );
      }
      throw StateError('SharedPrefsService storage is unavailable for delete($key).');
    }
    await deleteWithPrefs(prefs, key);
  }

  static Future<void> clear() async {
    await init();
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) {
      if (_initError != null) {
        Logger.warn(
          'SharedPrefsService clear skipped due to initialization failure: $_initError',
        );
      }
      throw StateError('SharedPrefsService storage is unavailable for clear().');
    }
    await _ensureMutationSucceeded(() => prefs.clear(), 'clear()');
  }

  static Future<void> saveStringWithPrefs(
    SharedPreferences prefs,
    String key,
    String value,
  ) {
    return _ensureMutationSucceeded(
      () => prefs.setString(key, value),
      'save($key)',
    );
  }

  static Future<void> saveBoolWithPrefs(
    SharedPreferences prefs,
    String key,
    bool value,
  ) {
    return _ensureMutationSucceeded(
      () => prefs.setBool(key, value),
      'saveBool($key)',
    );
  }

  static Future<void> saveIntWithPrefs(
    SharedPreferences prefs,
    String key,
    int value,
  ) {
    return _ensureMutationSucceeded(
      () => prefs.setInt(key, value),
      'saveInt($key)',
    );
  }

  static Future<void> deleteWithPrefs(
    SharedPreferences prefs,
    String key,
  ) async {
    if (!prefs.containsKey(key)) {
      return;
    }
    await _ensureMutationSucceeded(() => prefs.remove(key), 'delete($key)');
  }

  static Future<void> _ensureMutationSucceeded(
    Future<bool> Function() action,
    String label,
  ) async {
    final bool success = await action();
    if (!success) {
      throw StateError('SharedPrefsService mutation failed for $label.');
    }
  }

  static bool _looksSensitiveKey(String key) {
    final String lowered = key.toLowerCase();
    for (final String marker in _sensitiveKeyMarkers) {
      if (lowered.contains(marker)) {
        return true;
      }
    }
    return false;
  }
}
