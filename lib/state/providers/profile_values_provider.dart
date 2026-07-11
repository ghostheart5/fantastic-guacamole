// Package imports.
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/models/core_values_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileValuesStore {
  const ProfileValuesStore();

  static const String _key = 'profile_values';

  static Set<String> defaults() {
    return CoreValueType.values
        .map((CoreValueType item) => coreValueTitle(item))
        .toSet();
  }

  Set<String> load() {
    final String? raw = SharedPrefsService.load(_key);
    if (raw == null || raw.trim().isEmpty) {
      return defaults();
    }
    final Set<String> parsed = raw
        .split(',')
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toSet();
    if (parsed.isEmpty) {
      return defaults();
    }
    if (!parsed.contains(coreValueTitle(CoreValueType.purpose))) {
      parsed.add(coreValueTitle(CoreValueType.purpose));
    }
    return parsed;
  }

  Future<void> save(Set<String> values) {
    return SharedPrefsService.save(_key, values.join(','));
  }
}

final profileValuesStoreProvider = Provider<ProfileValuesStore>((_) {
  return const ProfileValuesStore();
});

final profileValuesProvider =
    NotifierProvider<ProfileValuesNotifier, Set<String>>(
      ProfileValuesNotifier.new,
    );

class ProfileValuesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    return ref.read(profileValuesStoreProvider).load();
  }

  Future<void> toggle(String value) async {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      return;
    }
    final Set<String> next = <String>{...state};
    if (next.contains(normalized)) {
      next.remove(normalized);
    } else {
      next.add(normalized);
    }
    state = next;
    await ref.read(profileValuesStoreProvider).save(next);
  }

  Future<void> setValues(Set<String> values) async {
    final Set<String> normalized = values
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toSet();
    state = normalized;
    await ref.read(profileValuesStoreProvider).save(normalized);
  }
}
