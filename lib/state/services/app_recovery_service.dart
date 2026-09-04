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
    String? activeTaskId,
    bool clearActiveTask = false,
    String? draftTaskTitle,
  }) async {
    try {
      if (lastRoute != null) {
        await _store.save(_kLastRoute, lastRoute);
      }
      if (clearActiveTask) {
        await _store.delete(_kTaskId);
      } else if (activeTaskId != null) {
        await _store.save(_kTaskId, activeTaskId);
      }
      if (draftTaskTitle != null) {
        await _store.save(_kDraftTitle, draftTaskTitle);
      }
    } on Object catch (error) {
      Logger.warn('App recovery state save failed: $error');
      // Non-fatal — recovery state is best-effort
    }
  }

  Future<AppRecoveryState?> loadState() async {
    try {
      final lastRoute = _store.load(_kLastRoute);
      final activeTaskId = _store.load(_kTaskId);
      final draftTitle = _store.load(_kDraftTitle);

      if (lastRoute == null && activeTaskId == null && draftTitle == null) {
        return null;
      }

      return AppRecoveryState(
        lastRoute: lastRoute,
        activeTaskId: activeTaskId,
        draftTaskTitle: draftTitle,
      );
    } on Object catch (error) {
      Logger.warn('App recovery state load failed: $error');
      return null;
    }
  }

  Future<void> clearDraft() async {
    try {
      await _store.delete(_kDraftTitle);
    } on Object catch (error) {
      Logger.warn('App recovery draft clear failed: $error');
    }
  }

  Future<void> clearAll() async {
    try {
      await _store.delete(_kLastRoute);
      await _store.delete(_kTaskId);
      await _store.delete(_kDraftTitle);
    } on Object catch (error) {
      Logger.warn('App recovery clear failed: $error');
    }
  }
}
