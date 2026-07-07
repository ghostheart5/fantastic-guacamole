// Package imports.
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileValuesStore {
  const ProfileValuesStore();

  static const String _key = 'profile_values';

  Set<String> load() {
    final String? raw = SharedPrefsService.load(_key);
    if (raw == null || raw.trim().isEmpty) {
      return <String>{};
    }
    return raw
        .split(',')
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toSet();
  }

  Future<void> save(Set<String> values) {
    return SharedPrefsService.save(_key, values.join(','));
  }
}

final profileValuesStoreProvider = Provider<ProfileValuesStore>((_) {
  return const ProfileValuesStore();
});
