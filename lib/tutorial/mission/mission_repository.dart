import 'dart:convert';

import 'package:fantastic_guacamole/core/errors/app_exception.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/tutorial/mission/mission_state.dart';

class MissionRepository {
  const MissionRepository({this.store = const SharedPrefsStoreAdapter()});

  static const String storageKey = 'mission_tutorial_progress_v1';

  final SharedPrefsStore store;

  Future<MissionState> load() async {
    await store.init();
    final String? raw = store.load(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return MissionState.initial();
    }

    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        return MissionState.fromJson(decoded);
      }
      if (decoded is Map) {
        return MissionState.fromJson(
          decoded.map(
            (Object? key, Object? value) => MapEntry(key.toString(), value),
          ),
        );
      }
      throw const StorageException('Mission progress storage is not an object.');
    } on FormatException {
      throw const StorageException('Mission progress storage is corrupted.');
    } on TypeError {
      throw const StorageException('Mission progress storage is corrupted.');
    }
  }

  Future<void> save(MissionState state) async {
    await store.init();
    await store.save(storageKey, jsonEncode(state.toJson()));
  }

  Future<void> reset() async {
    await store.init();
    await store.delete(storageKey);
  }
}
