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
    final Future<void> inFlight = _initFuture ??= () async {
      _prefs ??= await SharedPreferences.getInstance();
      if (!_didLogInitialized) {
        Logger.log('SharedPrefsService', 'Initialized');
        _didLogInitialized = true;
      }
    }();
    await inFlight;
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
      Logger.error(
        'SharedPrefsService save skipped because storage is unavailable.',
      );
      return;
    }
    await prefs.setString(key, value);
  }

  static String? load(String key) {
    return _prefs?.getString(key);
  }

  static Future<void> delete(String key) async {
    await init();
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) {
      Logger.error(
        'SharedPrefsService delete skipped because storage is unavailable.',
      );
      return;
    }
    await prefs.remove(key);
  }

  static Future<void> clear() async {
    await init();
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) {
      Logger.error(
        'SharedPrefsService clear skipped because storage is unavailable.',
      );
      return;
    }
    await prefs.clear();
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
