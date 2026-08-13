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
  SessionRecoveryService({required this._storageScope});

  static const _kLastRoute = 'rec_last_route';
  static const _kTaskId = 'rec_active_task';
  static const _kDraftTitle = 'rec_draft_title';
  final String _storageScope;
  bool _cancelled = false;
  Future<void> _mutationTail = Future<void>.value();

  String _key(String key) => '$key.$_storageScope';

  Future<void> cancelAndDrain() async {
    _cancelled = true;
    await _mutationTail.catchError((Object _) {});
  }

  void dispose() {
    _cancelled = true;
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final Future<void> previous = _mutationTail.catchError((Object _) {});
    final Future<void> next = previous.then((_) async {
      if (!_cancelled) {
        await operation();
      }
    });
    _mutationTail = next;
    return next;
  }

  Future<void> saveState({
    String? lastRoute,
    String? activeTaskId,
    bool clearActiveTask = false,
    String? draftTaskTitle,
  }) {
    return _serialize(() async {
      try {
        if (lastRoute != null) {
          await SharedPrefsService.save(_key(_kLastRoute), lastRoute);
        }
        if (_cancelled) return;
        if (clearActiveTask) {
          await SharedPrefsService.delete(_key(_kTaskId));
        } else if (activeTaskId != null) {
          await SharedPrefsService.save(_key(_kTaskId), activeTaskId);
        }
        if (_cancelled) return;
        if (draftTaskTitle != null) {
          await SharedPrefsService.save(_key(_kDraftTitle), draftTaskTitle);
        }
      } catch (_) {
        Logger.warn('Session recovery: saveState failed (non-fatal).');
        RuntimeDiagnostics.record(
          'Session recovery saveState failure observed (non-fatal).',
        );
      }
    });
  }

  Future<SessionRecoveryState?> loadState() async {
    try {
      await _mutationTail.catchError((Object _) {});
      if (_cancelled) return null;
      final lastRoute = SharedPrefsService.load(_key(_kLastRoute));
      final activeTaskId = SharedPrefsService.load(_key(_kTaskId));
      final draftTitle = SharedPrefsService.load(_key(_kDraftTitle));

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

  Future<void> clearDraft() {
    return _serialize(() async {
      try {
        await SharedPrefsService.delete(_key(_kDraftTitle));
      } catch (_) {
        Logger.warn('Session recovery: clearDraft failed (non-fatal).');
        RuntimeDiagnostics.record(
          'Session recovery clearDraft failure observed (non-fatal).',
        );
      }
    });
  }

  Future<void> clearAll() {
    return _serialize(() async {
      try {
        await SharedPrefsService.delete(_key(_kLastRoute));
        if (_cancelled) return;
        await SharedPrefsService.delete(_key(_kTaskId));
        if (_cancelled) return;
        await SharedPrefsService.delete(_key(_kDraftTitle));
      } catch (_) {
        Logger.warn('Session recovery: clearAll failed (non-fatal).');
        RuntimeDiagnostics.record(
          'Session recovery clearAll failure observed (non-fatal).',
        );
      }
    });
  }
}
