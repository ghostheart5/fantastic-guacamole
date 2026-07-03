import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class SharedPrefsStore {
  Future<void> init();
  Future<void> save(String key, String value);
  String? load(String key);
  Future<void> delete(String key);
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
}

class SharedPrefsService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    Logger.log('SharedPrefsService', 'Initialized');
  }

  static Future<void> save(String key, String value) async {
    await init();
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
}
