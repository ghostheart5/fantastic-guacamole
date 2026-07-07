// Dart SDK imports.
import 'dart:convert';

// Package imports.
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/session_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_session_repository.dart';

class SessionRepository implements ISessionRepository {
  SessionRepository(this._store);

  static const String _sessionsKey = 'sessions_entity_v1';
  final SecureStore _store;

  @override
  Future<void> startSession(SessionEntity session) async {
    final List<SessionEntity> sessions = await _allSessions();
    final List<SessionEntity> updated = <SessionEntity>[
      session,
      ...sessions.where((SessionEntity item) => item.id != session.id),
    ];
    await _saveAll(updated);
  }

  @override
  Future<void> endSession(String sessionId, DateTime endedAt) async {
    final List<SessionEntity> sessions = await _allSessions();
    final List<SessionEntity> updated = sessions.map((SessionEntity item) {
      if (item.id != sessionId) {
        return item;
      }
      return SessionEntity(
        id: item.id,
        taskId: item.taskId,
        startedAt: item.startedAt,
        plannedDuration: item.plannedDuration,
        endedAt: endedAt,
      );
    }).toList();
    await _saveAll(updated);
  }

  @override
  Future<void> pauseSession(String sessionId, DateTime pausedAt) async {
    final List<SessionEntity> sessions = await _allSessions();
    final bool exists = sessions.any(
      (SessionEntity item) => item.id == sessionId,
    );
    if (!exists) {
      return;
    }
  }

  @override
  Future<void> resumeSession(String sessionId, DateTime resumedAt) async {
    final List<SessionEntity> sessions = await _allSessions();
    final bool exists = sessions.any(
      (SessionEntity item) => item.id == sessionId,
    );
    if (!exists) {
      return;
    }
  }

  @override
  Future<List<SessionEntity>> getSessionsForTask(String taskId) async {
    final List<SessionEntity> sessions = await _allSessions();
    return sessions
        .where((SessionEntity item) => item.taskId == taskId)
        .toList();
  }

  Future<List<SessionEntity>> _allSessions() async {
    final String? raw = await _store.readString(_sessionsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <SessionEntity>[];
    }

    final Object? decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      return const <SessionEntity>[];
    }

    final List<SessionEntity> sessions = <SessionEntity>[];
    for (final Object? value in decoded) {
      if (value is! Map) {
        continue;
      }
      final Map<String, dynamic> json = value.map(
        (dynamic key, dynamic item) => MapEntry(key.toString(), item),
      );
      final DateTime startedAt =
          DateTime.tryParse((json['startedAt'] as String?) ?? '') ??
          DateTime.now();
      final DateTime? endedAt = DateTime.tryParse(
        (json['endedAt'] as String?) ?? '',
      );
      final int plannedMs = (json['plannedDurationMs'] as num?)?.toInt() ?? 0;
      sessions.add(
        SessionEntity(
          id: (json['id'] as String?) ?? '',
          taskId: (json['taskId'] as String?) ?? '',
          startedAt: startedAt,
          endedAt: endedAt,
          plannedDuration: Duration(milliseconds: plannedMs),
        ),
      );
    }
    return sessions;
  }

  Future<void> _saveAll(List<SessionEntity> sessions) {
    return _store.writeString(
      _sessionsKey,
      jsonEncode(
        sessions
            .map((SessionEntity item) {
              return <String, dynamic>{
                'id': item.id,
                'taskId': item.taskId,
                'startedAt': item.startedAt.toIso8601String(),
                'endedAt': item.endedAt?.toIso8601String(),
                'plannedDurationMs': item.plannedDuration.inMilliseconds,
              };
            })
            .toList(growable: false),
      ),
    );
  }
}
