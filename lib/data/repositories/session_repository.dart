// Dart SDK imports.
import 'dart:convert';

// Package imports.
import 'package:fantastic_guacamole/core/debug/logger.dart';
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

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      Logger.error('Session storage is corrupted.', error);
      throw StateError(
        'Session storage is corrupted. Refusing to treat it as empty history.',
      );
    }
    if (decoded is! List<dynamic>) {
      Logger.error('Session storage is corrupted: top-level payload is not a list.');
      throw StateError(
        'Session storage is corrupted. Refusing to treat it as empty history.',
      );
    }

    final List<SessionEntity> sessions = <SessionEntity>[];
    int malformedCount = 0;
    for (final Object? value in decoded) {
      if (value is! Map) {
        malformedCount++;
        continue;
      }
      final Map<String, dynamic> json = value.map(
        (dynamic key, dynamic item) => MapEntry(key.toString(), item),
      );
      final String id = (json['id'] as String?) ?? '';
      final String taskId = (json['taskId'] as String?) ?? '';
      final DateTime? startedAt = DateTime.tryParse(
        (json['startedAt'] as String?) ?? '',
      );
      if (id.trim().isEmpty || taskId.trim().isEmpty || startedAt == null) {
        malformedCount++;
        continue;
      }
      final DateTime? endedAt = DateTime.tryParse(
        (json['endedAt'] as String?) ?? '',
      );
      final int plannedMs = (json['plannedDurationMs'] as num?)?.toInt() ?? 0;
      sessions.add(
        SessionEntity(
          id: id,
          taskId: taskId,
          startedAt: startedAt,
          endedAt: endedAt,
          plannedDuration: Duration(milliseconds: plannedMs),
        ),
      );
    }
    if (malformedCount > 0) {
      Logger.warn('Skipped $malformedCount malformed session entries.');
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
