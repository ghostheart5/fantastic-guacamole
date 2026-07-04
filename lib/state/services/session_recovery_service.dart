import 'package:fantastic_guacamole/core/storage/shared_prefs_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class SessionRecoveryState {
  const SessionRecoveryState({
    this.lastRoute,
    this.activeTaskId,
    this.focusSessionActive = false,
    this.focusStartTime,
    this.draftTaskTitle,
  });

  final String? lastRoute;
  final String? activeTaskId;
  final bool focusSessionActive;
  final DateTime? focusStartTime;
  final String? draftTaskTitle;
}

class SessionRecoveryService {
  static const _kLastRoute = 'rec_last_route';
  static const _kTaskId = 'rec_active_task';
  static const _kFocusActive = 'rec_focus_active';
  static const _kFocusStart = 'rec_focus_start';
  static const _kDraftTitle = 'rec_draft_title';

  Future<void> saveState({
    String? lastRoute,
    String? activeTaskId,
    bool? focusSessionActive,
    DateTime? focusStartTime,
    String? draftTaskTitle,
  }) async {
    try {
      if (lastRoute != null) {
        await SharedPrefsService.save(_kLastRoute, lastRoute);
      }
      if (activeTaskId != null) {
        await SharedPrefsService.save(_kTaskId, activeTaskId);
      }
      if (focusSessionActive != null) {
        await SharedPrefsService.save(
          _kFocusActive,
          focusSessionActive.toString(),
        );
      }
      if (focusStartTime != null) {
        await SharedPrefsService.save(
          _kFocusStart,
          focusStartTime.toIso8601String(),
        );
      }
      if (draftTaskTitle != null) {
        await SharedPrefsService.save(_kDraftTitle, draftTaskTitle);
      }
    } catch (_) {
      // Non-fatal — recovery state is best-effort
    }
  }

  Future<SessionRecoveryState?> loadState() async {
    try {
      final lastRoute = SharedPrefsService.load(_kLastRoute);
      final activeTaskId = SharedPrefsService.load(_kTaskId);
      final focusActiveRaw = SharedPrefsService.load(_kFocusActive);
      final focusStartRaw = SharedPrefsService.load(_kFocusStart);
      final draftTitle = SharedPrefsService.load(_kDraftTitle);

      final focusActive = focusActiveRaw == 'true';
      DateTime? focusStart;
      if (focusStartRaw != null) {
        focusStart = DateTime.tryParse(focusStartRaw);
      }

      if (lastRoute == null && !focusActive && draftTitle == null) return null;

      return SessionRecoveryState(
        lastRoute: lastRoute,
        activeTaskId: activeTaskId,
        focusSessionActive: focusActive,
        focusStartTime: focusStart,
        draftTaskTitle: draftTitle,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearFocus() async {
    try {
      await SharedPrefsService.save(_kFocusActive, 'false');
      await SharedPrefsService.delete(_kFocusStart);
      await SharedPrefsService.delete(_kTaskId);
    } catch (_) {}
  }

  Future<void> clearDraft() async {
    try {
      await SharedPrefsService.delete(_kDraftTitle);
    } catch (_) {}
  }

  Future<void> clearAll() async {
    try {
      await SharedPrefsService.delete(_kLastRoute);
      await SharedPrefsService.delete(_kTaskId);
      await SharedPrefsService.save(_kFocusActive, 'false');
      await SharedPrefsService.delete(_kFocusStart);
      await SharedPrefsService.delete(_kDraftTitle);
    } catch (_) {}
  }
}

final sessionRecoveryProvider = Provider<SessionRecoveryService>(
  (_) => SessionRecoveryService(),
);
