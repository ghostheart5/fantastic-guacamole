import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:flutter/foundation.dart';

@immutable
class SessionRecoveryState {
  const SessionRecoveryState({
    this.lastRoute,
    this.activeTaskId,
    this.draftTaskTitle,
  });

  final String? lastRoute;
  final String? activeTaskId;
  final String? draftTaskTitle;
}

class SessionRecoveryService {
  static const _kLastRoute = 'rec_last_route';
  static const _kTaskId = 'rec_active_task';
  static const _kDraftTitle = 'rec_draft_title';

  Future<void> saveState({
    String? lastRoute,
    String? activeTaskId,
    bool clearActiveTask = false,
    String? draftTaskTitle,
  }) async {
    try {
      if (lastRoute != null) {
        await SharedPrefsService.save(_kLastRoute, lastRoute);
      }
      if (clearActiveTask) {
        await SharedPrefsService.delete(_kTaskId);
      } else if (activeTaskId != null) {
        await SharedPrefsService.save(_kTaskId, activeTaskId);
      }
      if (draftTaskTitle != null) {
        await SharedPrefsService.save(_kDraftTitle, draftTaskTitle);
      }
    } catch (_) {
      Logger.warn('Session recovery: saveState failed (non-fatal).');
      RuntimeDiagnostics.record(
        'Session recovery saveState failure observed (non-fatal).',
      );
    }
  }

  Future<SessionRecoveryState?> loadState() async {
    try {
      final lastRoute = SharedPrefsService.load(_kLastRoute);
      final activeTaskId = SharedPrefsService.load(_kTaskId);
      final draftTitle = SharedPrefsService.load(_kDraftTitle);

      if (lastRoute == null && draftTitle == null) return null;

      return SessionRecoveryState(
        lastRoute: lastRoute,
        activeTaskId: activeTaskId,
        draftTaskTitle: draftTitle,
      );
    } catch (_) {
      Logger.warn('Session recovery: loadState failed (non-fatal).');
      RuntimeDiagnostics.record(
        'Session recovery loadState failure observed (non-fatal).',
      );
      return null;
    }
  }

  Future<void> clearDraft() async {
    try {
      await SharedPrefsService.delete(_kDraftTitle);
    } catch (_) {
      Logger.warn('Session recovery: clearDraft failed (non-fatal).');
      RuntimeDiagnostics.record(
        'Session recovery clearDraft failure observed (non-fatal).',
      );
    }
  }

  Future<void> clearAll() async {
    try {
      await SharedPrefsService.delete(_kLastRoute);
      await SharedPrefsService.delete(_kTaskId);
      await SharedPrefsService.delete(_kDraftTitle);
    } catch (_) {
      Logger.warn('Session recovery: clearAll failed (non-fatal).');
      RuntimeDiagnostics.record(
        'Session recovery clearAll failure observed (non-fatal).',
      );
    }
  }
}
