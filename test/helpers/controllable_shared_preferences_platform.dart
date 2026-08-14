import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class ControllableSharedPreferencesPlatform
    extends SharedPreferencesStorePlatform {
  ControllableSharedPreferencesPlatform([Map<String, Object>? initialValues])
      : values = <String, Object>{...?initialValues};

  final Map<String, Object> values;
  bool failGetAll = false;
  bool failSetValue = false;
  int getAllCalls = 0;
  int setValueCalls = 0;

  @override
  Future<Map<String, Object>> getAll() async {
    getAllCalls++;
    if (failGetAll) throw StateError('test getAll failure');
    return Map<String, Object>.from(values);
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    setValueCalls++;
    if (failSetValue) throw StateError('test setValue failure');
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    values.clear();
    return true;
  }
}
