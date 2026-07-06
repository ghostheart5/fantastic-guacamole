import 'dart:convert';

import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_progress_store.dart';

class TutorialRepository {
  const TutorialRepository();

  static const String _storageKey = 'tutorial_progress_v1';

  TutorialProgress loadProgress() {
    final String? raw = SharedPrefsService.load(_storageKey);

    if (raw == null || raw.trim().isEmpty) {
      return const TutorialProgress();
    }

    try {
      final dynamic decoded = jsonDecode(raw);

      if (decoded is Map<String, dynamic>) {
        return TutorialProgress.fromJson(decoded);
      }

      if (decoded is Map) {
        return TutorialProgress.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }

      return const TutorialProgress();
    } on FormatException {
      return const TutorialProgress();
    } catch (_) {
      return const TutorialProgress();
    }
  }

  Future<TutorialProgress> loadProgressWithVersion({required int contentVersion}) async {
    final TutorialProgress current = loadProgress();

    if (current.contentVersion == contentVersion) {
      return current;
    }

    final TutorialProgress migrated = current.applyContentVersion(contentVersion);

    await saveProgress(migrated);

    return migrated;
  }

  Future<void> saveProgress(TutorialProgress progress) async {
    await SharedPrefsService.save(_storageKey, jsonEncode(progress.toJson()));
  }

  Future<void> resetProgress() async {
    await SharedPrefsService.delete(_storageKey);
  }

  Future<void> resetToVersion({required int contentVersion}) async {
    await saveProgress(TutorialProgress(contentVersion: contentVersion));
  }

  Future<bool> hasProgress() async {
    final String? raw = SharedPrefsService.load(_storageKey);

    return raw != null && raw.trim().isNotEmpty;
  }

  Future<void> removeProgress() async {
    await SharedPrefsService.delete(_storageKey);
  }
}
