import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:flutter/foundation.dart';

@immutable
class AppRecoveryState {
  const AppRecoveryState({
    this.lastRoute,
    this.activeTaskId,
    this.draftTaskTitle,
  });

  final String? lastRoute;
  final String? activeTaskId;
  final String? draftTaskTitle;
}

class AppRecoveryService {
  AppRecoveryService({SharedPrefsStore? store})
    : _store = store ?? const SharedPrefsStoreAdapter();

  static const _kLastRoute = 'rec_last_route';
  static const _kTaskId = 'rec_active_task';
  static const _kDraftTitle = 'rec_draft_title';
  final SharedPrefsStore _store;

  Future<void> saveState({
    String? lastRoute,
    bool clearLastRoute = false,
    String? activeTaskId,
    bool clearActiveTask = false,
    String? draftTaskTitle,
    bool clearDraftTitle = false,
  }) async {
    try {
      if (clearLastRoute) {
        await _store.delete(_kLastRoute);
      } else if (lastRoute != null) {
        await _saveNormalized(_kLastRoute, lastRoute);
      }
      if (clearActiveTask) {
        await _store.delete(_kTaskId);
      } else if (activeTaskId != null) {
        await _saveNormalized(_kTaskId, activeTaskId);
      }
      if (clearDraftTitle) {
        await _store.delete(_kDraftTitle);
      } else if (draftTaskTitle != null) {
        await _saveNormalized(_kDraftTitle, draftTaskTitle);
      }
    } on Object catch (error) {
      Logger.warn('RECOVERY_SAVE_FAILED: $error');
      // Non-fatal — recovery state is best-effort
    }
  }

  Future<void> _saveNormalized(String key, String value) async {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      await _store.delete(key);
      return;
    }
    await _store.save(key, normalized);
  }

  Future<AppRecoveryState?> loadState() async {
    try {
      final String? lastRoute = _normalizedOrNull(_store.load(_kLastRoute));
      final String? activeTaskId = _normalizedOrNull(_store.load(_kTaskId));
      final String? draftTitle = _normalizedOrNull(_store.load(_kDraftTitle));

      if (lastRoute == null && activeTaskId == null && draftTitle == null) {
        return null;
      }

      return AppRecoveryState(
        lastRoute: lastRoute,
        activeTaskId: activeTaskId,
        draftTaskTitle: draftTitle,
      );
    } on Object catch (error) {
      Logger.warn('RECOVERY_LOAD_FAILED: $error');
      return null;
    }
  }

  String? _normalizedOrNull(String? value) {
    final String normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> clearDraft() async {
    await saveState(clearDraftTitle: true);
  }

  Future<void> clearAll() async {
    try {
      await _store.delete(_kLastRoute);
      await _store.delete(_kTaskId);
      await _store.delete(_kDraftTitle);
    } on Object catch (error) {
      Logger.warn('RECOVERY_CLEAR_FAILED: $error');
    }
  }
}
