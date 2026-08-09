import 'package:fantastic_guacamole/data/repositories/session_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/session_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SessionRepository repository;
  final DateTime startedAt = DateTime.utc(2026, 8, 4, 9);

  setUp(() async {
    repository = SessionRepository(
      SecureStore(backend: InMemorySecureStoreBackend()),
    );
    await repository.startSession(
      SessionEntity(
        id: 'session-1',
        taskId: 'task-1',
        startedAt: startedAt,
        plannedDuration: const Duration(hours: 2),
      ),
    );
  });

  Future<SessionEntity> load() async {
    return (await repository.getSessionsForTask('task-1')).single;
  }

  test('pauses and persists a session', () async {
    final DateTime pausedAt = startedAt.add(const Duration(minutes: 20));

    await repository.pauseSession('session-1', pausedAt);

    final SessionEntity session = await load();
    expect(session.pausedAt, pausedAt);
    expect(session.pausedDuration, Duration.zero);
    expect(session.isPaused, isTrue);
  });

  test('resumes and accumulates paused duration', () async {
    final DateTime pausedAt = startedAt.add(const Duration(minutes: 20));
    final DateTime resumedAt = pausedAt.add(const Duration(minutes: 15));
    await repository.pauseSession('session-1', pausedAt);

    await repository.resumeSession('session-1', resumedAt);

    final SessionEntity session = await load();
    expect(session.pausedAt, isNull);
    expect(session.pausedDuration, const Duration(minutes: 15));
    expect(session.isPaused, isFalse);
  });

  test('double pause is idempotent', () async {
    final DateTime firstPause = startedAt.add(const Duration(minutes: 20));
    await repository.pauseSession('session-1', firstPause);

    await repository.pauseSession(
      'session-1',
      firstPause.add(const Duration(minutes: 10)),
    );

    expect((await load()).pausedAt, firstPause);
  });

  test('double resume is idempotent', () async {
    final DateTime pausedAt = startedAt.add(const Duration(minutes: 20));
    await repository.pauseSession('session-1', pausedAt);
    await repository.resumeSession(
      'session-1',
      pausedAt.add(const Duration(minutes: 10)),
    );

    await repository.resumeSession(
      'session-1',
      pausedAt.add(const Duration(minutes: 20)),
    );

    expect((await load()).pausedDuration, const Duration(minutes: 10));
  });

  test('ending a paused session records the active paused duration', () async {
    final DateTime pausedAt = startedAt.add(const Duration(minutes: 20));
    final DateTime endedAt = pausedAt.add(const Duration(minutes: 15));
    await repository.pauseSession('session-1', pausedAt);

    await repository.endSession('session-1', endedAt);

    final SessionEntity session = await load();
    expect(session.endedAt, endedAt);
    expect(session.pausedAt, isNull);
    expect(session.pausedDuration, const Duration(minutes: 15));
    expect(session.actualDuration, const Duration(minutes: 20));
  });
}
