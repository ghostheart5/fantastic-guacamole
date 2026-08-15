import 'dart:io';
import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/adapters/note_timeline_adapter.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/remote/goals_remote_gateway.dart';
import 'package:fantastic_guacamole/data/remote/habit_occurrences_remote_gateway.dart';
import 'package:fantastic_guacamole/data/remote/habits_remote_gateway.dart';
import 'package:fantastic_guacamole/data/remote/notes_remote_gateway.dart';
import 'package:fantastic_guacamole/data/remote/settings_remote_gateway.dart';
import 'package:fantastic_guacamole/data/remote/tasks_remote_gateway.dart';
import 'package:fantastic_guacamole/data/repositories/note_repository.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/sync/sync_mutation_dispatcher.dart';
import 'package:fantastic_guacamole/data/sync/sync_operation.dart';
import 'package:fantastic_guacamole/data/sync/sync_queue_store.dart';
import 'package:fantastic_guacamole/data/sync/sync_result.dart';
import 'package:fantastic_guacamole/data/sync/sync_runner.dart';
import 'package:fantastic_guacamole/data/sync/supabase_sync_executor.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../helpers/real_hive_test_fixture.dart';

class _Timeline implements ITimelineRepository {
  final List<TimelineEventEntity> values = <TimelineEventEntity>[];
  bool fail = false;
  @override List<TimelineEventEntity> getEvents() => List<TimelineEventEntity>.from(values);
  @override Future<void> addEvent(TimelineEventEntity event) async {
    if (fail) throw StateError('projection failed');
    values.add(event);
  }
  @override Future<void> removeEvent(String id) async => values.removeWhere((TimelineEventEntity event) => event.id == id);
  @override Future<void> saveEvents(List<TimelineEventEntity> events) async { values..clear()..addAll(events); }
}

class _Queue implements SyncQueueStoreContract {
  final List<SyncOperation> values = <SyncOperation>[];
  @override Future<List<SyncOperation>> readAll() async => List<SyncOperation>.from(values);
  @override Future<void> overwrite(List<SyncOperation> items) async { values..clear()..addAll(items); }
  @override Future<void> enqueue(SyncOperation item) async => values.add(item);
  @override Future<void> removeById(String id) async => values.removeWhere((SyncOperation item) => item.operationId == id);
  @override Future<void> update(SyncOperation updated) async => overwrite(values.map((SyncOperation item) => item.operationId == updated.operationId ? updated : item).toList());
}

class _HiveStore implements HiveStore {
  const _HiveStore();
  @override Box<T> box<T>(String key) => Hive.box<T>(key);
  @override Future<void> clearBox(String key) async => Hive.box<dynamic>(key).clear();
  @override Future<void> closeBox(String key) async => Hive.box<dynamic>(key).close();
  @override Future<void> init() async {}
  @override bool isBoxOpen(String key) => Hive.isBoxOpen(key);
  @override Future<Box<T>> openBox<T>(String key) => Hive.openBox<T>(key);
}

class _GatewayTransport extends http.BaseClient {
  final List<_GatewayRequest> requests = <_GatewayRequest>[];
  bool failWithRetryableResponse = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final String body = await utf8.decoder.bind(request.finalize()).join();
    requests.add(_GatewayRequest(request.method, request.url, body));
    if (failWithRetryableResponse) {
      return http.StreamedResponse(
        Stream<List<int>>.value(
          utf8.encode('{"message":"network unavailable","code":"503"}'),
        ),
        503,
        headers: const <String, String>{'content-type': 'application/json'},
        request: request,
      );
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode('[]')),
      201,
      headers: const <String, String>{'content-type': 'application/json'},
      request: request,
    );
  }
}

class _GatewayRequest {
  const _GatewayRequest(this.method, this.uri, this.body);
  final String method;
  final Uri uri;
  final String body;
}

class _GatewayClient extends sb.SupabaseClient {
  _GatewayClient(this._auth, _GatewayTransport transport)
      : super(
          'https://example.supabase.co',
          'public-anon-key',
          httpClient: transport,
        );

  final sb.GoTrueClient _auth;

  @override
  sb.GoTrueClient get auth => _auth;
}

class _GatewayAuth extends sb.GoTrueClient {
  _GatewayAuth(String userId)
      : _user = sb.User.fromJson(<String, dynamic>{
          'id': userId,
          'aud': 'authenticated',
          'created_at': DateTime.utc(2026, 8, 15).toIso8601String(),
        })!,
        super(url: 'https://example.supabase.co');

  final sb.User _user;

  @override
  sb.User get currentUser => _user;
}

SyncQueueStore _queue(RealHiveTestFixture fixture, AccountStorageScope scope) =>
    SyncQueueStore(
      HiveStorage<String>(
        HiveBoxes.accountScoped(HiveBoxes.offlineQueue, scope),
        hive: fixture.hiveStore,
      ),
      storageScope: scope,
    );

NoteRepository _repository(
  RealHiveTestFixture fixture,
  AccountStorageScope scope,
  SyncMutationDispatcher dispatcher,
) => NoteRepository(
  HiveStorage<String>(
    HiveBoxes.accountScoped(HiveBoxes.notes, scope),
    hive: fixture.hiveStore,
  ),
  syncDispatcher: dispatcher,
);

NoteEntity _note(String title, {bool archived = false}) => NoteEntity(
  id: 'same-note', title: title, body: '$title body',
  createdAt: DateTime.utc(2026, 8, 15, 10), updatedAt: DateTime.utc(2026, 8, 15, 11), isArchived: archived,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => Hive.init(Directory.systemTemp.createTempSync('note-b2-').path));

  test('Note Timeline projection is deterministic, typed, and retry-safe', () async {
    final _Timeline timeline = _Timeline();
    final NoteTimelineAdapter adapter = NoteTimelineAdapter(timeline);
    final NoteEntity note = _note('A_NOTE');
    await adapter.record(note, NoteTimelineMutation.created);
    await adapter.record(note, NoteTimelineMutation.created);
    await adapter.record(note.copyWith(title: 'A_EDITED', updatedAt: DateTime.utc(2026, 8, 15, 12)), NoteTimelineMutation.updated);
    await adapter.record(note.copyWith(isArchived: true, updatedAt: DateTime.utc(2026, 8, 15, 13)), NoteTimelineMutation.archived);
    expect(timeline.values.map((TimelineEventEntity event) => event.type), <TimelineEventType>[
      TimelineEventType.noteCreated, TimelineEventType.noteUpdated, TimelineEventType.noteArchived,
    ]);
    expect(timeline.values.first.id, 'note:same-note:created:1786791600000000');
    timeline.fail = true;
    await expectLater(adapter.record(note.copyWith(updatedAt: DateTime.utc(2026, 8, 15, 14)), NoteTimelineMutation.deleted), throwsStateError);
    timeline.fail = false;
    await adapter.record(note.copyWith(updatedAt: DateTime.utc(2026, 8, 15, 14)), NoteTimelineMutation.deleted);
    expect(timeline.values.last.type, TimelineEventType.noteDeleted);
  });

  test('Note local persistence queues one account-owned canonical sync mutation and retries', () async {
    final AccountStorageScope scope = AccountStorageScope.authenticated('note-sync-a');
    final _Queue queue = _Queue();
    final NoteRepository repository = NoteRepository(
      HiveStorage<String>(HiveBoxes.accountScoped(HiveBoxes.notes, scope), hive: const _HiveStore()),
      syncDispatcher: SyncMutationDispatcher(queueStore: queue, userId: 'note-sync-a'),
    );
    await repository.save(_note('A_NOTE'));
    await repository.save(_note('A_NOTE'));
    expect((await repository.getNotes()).single.title, 'A_NOTE');
    expect(queue.values, hasLength(1));
    final SyncOperation operation = queue.values.single;
    expect(operation.tableName, 'notes');
    expect(operation.userId, 'note-sync-a');
    expect(operation.payload, containsPair('title', 'A_NOTE'));
    expect(operation.payload, containsPair('body', 'A_NOTE body'));
    final SyncRunner failing = SyncRunner(queueStore: queue, applyFn: (_) async => SyncApplyResult.retryable('network unavailable'));
    await failing.runOnce();
    expect(queue.values.single.retryCount, 1);
    final SyncRunner retry = SyncRunner(queueStore: queue, now: () => DateTime.utc(2026, 8, 16), applyFn: (_) async => SyncApplyResult.success());
    await retry.runOnce();
    expect(queue.values, isEmpty);
    expect((await repository.getNotes()).single.title, 'A_NOTE');
  });

  test('Note Sync keeps matching logical ids isolated by account and rejects signed-out dispatch', () async {
    final _Queue a = _Queue();
    final _Queue b = _Queue();
    final NoteEntity note = _note('SAME_ID');
    await SyncMutationDispatcher(queueStore: a, userId: 'A').enqueueUpsert(tableName: 'notes', recordId: note.id, payload: note.toJson());
    await SyncMutationDispatcher(queueStore: b, userId: 'B').enqueueUpsert(tableName: 'notes', recordId: note.id, payload: note.toJson());
    expect(a.values.single.userId, 'A');
    expect(b.values.single.userId, 'B');
    expect(await SyncMutationDispatcher(queueStore: _Queue(), userId: null).enqueueUpsert(tableName: 'notes', recordId: note.id, payload: note.toJson()), isFalse);
  });

  test('Note Sync restores an A-owned retry after real-Hive runtime recreation and keeps B isolated', () async {
    final RealHiveTestFixture fixture = await RealHiveTestFixture.create();
    addTearDown(fixture.dispose);
    final AccountStorageScope a = AccountStorageScope.authenticated('note-restart-a');
    final AccountStorageScope b = AccountStorageScope.authenticated('note-restart-b');
    final SyncQueueStore aQueue = _queue(fixture, a);
    final SyncMutationDispatcher firstDispatcher = SyncMutationDispatcher(queueStore: aQueue, userId: 'note-restart-a');
    final NoteRepository first = _repository(fixture, a, firstDispatcher);
    final NoteEntity note = _note('A_RESTART_NOTE');
    await first.save(note);
    await SyncRunner(
      queueStore: aQueue,
      now: () => DateTime.utc(2026, 8, 15, 12),
      applyFn: (_) async => SyncApplyResult.retryable('network unavailable'),
    ).runOnce();
    expect((await aQueue.readAll()).single.retryCount, 1);
    await first.cancelAndDrain();
    first.dispose();

    final SyncQueueStore restartedQueue = _queue(fixture, a);
    final NoteRepository restarted = _repository(
      fixture,
      a,
      SyncMutationDispatcher(queueStore: restartedQueue, userId: 'note-restart-a'),
    );
    expect((await restarted.getNotes()).single.id, note.id);
    expect((await restartedQueue.readAll()).single.recordId, note.id);
    final List<SyncOperation> applied = <SyncOperation>[];
    await SyncRunner(
      queueStore: restartedQueue,
      now: () => DateTime.utc(2026, 8, 16),
      applyFn: (SyncOperation operation) async {
        applied.add(operation);
        return SyncApplyResult.success();
      },
    ).runOnce();
    expect(applied.single.recordId, note.id);
    expect(await restartedQueue.readAll(), isEmpty);
    expect(await restarted.getNotes(), hasLength(1));

    final SyncQueueStore bQueue = _queue(fixture, b);
    final NoteRepository bRepository = _repository(
      fixture,
      b,
      SyncMutationDispatcher(queueStore: bQueue, userId: 'note-restart-b'),
    );
    expect(await bRepository.getNotes(), isEmpty);
    expect(await bQueue.readAll(), isEmpty);
    await bRepository.save(_note('B_SAME_NOTE'));
    expect((await bQueue.readAll()).single.userId, 'note-restart-b');
    expect((await bRepository.getNotes()).single.title, 'B_SAME_NOTE');
    expect((await restarted.getNotes()).single.title, 'A_RESTART_NOTE');
  });

  test('retained Note dispatcher remains bound to A and cannot enqueue into B', () async {
    final RealHiveTestFixture fixture = await RealHiveTestFixture.create();
    addTearDown(fixture.dispose);
    final AccountStorageScope a = AccountStorageScope.authenticated('note-stale-a');
    final AccountStorageScope b = AccountStorageScope.authenticated('note-stale-b');
    final SyncQueueStore aQueue = _queue(fixture, a);
    final SyncQueueStore bQueue = _queue(fixture, b);
    final SyncMutationDispatcher staleA = SyncMutationDispatcher(queueStore: aQueue, userId: 'note-stale-a');
    _repository(fixture, b, SyncMutationDispatcher(queueStore: bQueue, userId: 'note-stale-b'));
    expect(
      await staleA.enqueueUpsert(
        tableName: 'notes',
        recordId: 'same-note',
        payload: _note('STALE_A').toJson(),
      ),
      isTrue,
    );
    expect((await aQueue.readAll()).single.userId, 'note-stale-a');
    expect(await bQueue.readAll(), isEmpty);
  });

  test('real NotesRemoteGateway maps owned Note rows and SupabaseSyncExecutor dispatches only notes', () async {
    final _GatewayTransport transport = _GatewayTransport();
    final NotesRemoteGateway notes = NotesRemoteGateway(
      _GatewayClient(_GatewayAuth('note-gateway-a'), transport),
    );
    final SupabaseSyncExecutor executor = SupabaseSyncExecutor(
      tasksGateway: const TasksRemoteGateway(null),
      goalsGateway: const GoalsRemoteGateway(null),
      habitsGateway: const HabitsRemoteGateway(null),
      habitOccurrencesGateway: const HabitOccurrencesRemoteGateway(null),
      settingsGateway: const SettingsRemoteGateway(null),
      notesGateway: notes,
    );
    final NoteEntity note = _note('GATEWAY_NOTE');
    final SyncOperation operation = SyncOperation(
      operationId: 'note-operation', tableName: 'notes', recordId: note.id,
      operationType: SyncOperationType.update,
      payload: <String, dynamic>{
        'id': note.id, 'title': note.title, 'body': note.body,
        'created_at': note.createdAt.toIso8601String(),
        'updated_at': note.updatedAt.toIso8601String(),
        'is_archived': false, 'goal_id': note.goalId,
      },
      userId: 'note-gateway-a', createdAtUtc: DateTime.utc(2026, 8, 15),
      retryCount: 0, nextRetryAtUtc: null, lastError: null,
    );
    expect((await executor.apply(operation)).ok, isTrue);
    final _GatewayRequest request = transport.requests.single;
    expect(request.method, 'POST');
    expect(request.uri.path, '/rest/v1/notes');
    expect(request.uri.queryParameters['on_conflict'], 'user_id,id');
    final Map<String, dynamic> row = jsonDecode(request.body) as Map<String, dynamic>;
    expect(row, containsPair('id', note.id));
    expect(row, containsPair('title', 'GATEWAY_NOTE'));
    expect(row, containsPair('user_id', 'note-gateway-a'));
    expect(row, isNot(contains('task_id')));

    transport.failWithRetryableResponse = true;
    final SyncApplyResult failed = await executor.apply(operation);
    expect(failed.ok, isFalse);
    expect(failed.shouldRetry, isTrue);
  });

  test('SupabaseSyncExecutor uniformly catches non-retryable async gateway failures', () async {
    const SupabaseSyncExecutor executor = SupabaseSyncExecutor(
      tasksGateway: TasksRemoteGateway(null),
      goalsGateway: GoalsRemoteGateway(null),
      habitsGateway: HabitsRemoteGateway(null),
      habitOccurrencesGateway: HabitOccurrencesRemoteGateway(null),
      settingsGateway: SettingsRemoteGateway(null),
      notesGateway: NotesRemoteGateway(null),
    );
    for (final String tableName in <String>[
      'tasks',
      'goals',
      'habits',
      'habit_occurrences',
      'settings',
      'notes',
    ]) {
      final SyncApplyResult result = await executor.apply(SyncOperation(
        operationId: '$tableName-operation',
        tableName: tableName,
        recordId: 'record',
        operationType: SyncOperationType.update,
        payload: const <String, dynamic>{'id': 'record'},
        userId: 'owner',
        createdAtUtc: DateTime.utc(2026, 8, 15),
        retryCount: 0,
        nextRetryAtUtc: null,
        lastError: null,
      ));
      expect(result.ok, isFalse, reason: tableName);
      expect(result.shouldRetry, isFalse, reason: tableName);
      expect(result.error, contains('not available'), reason: tableName);
    }
  });

  test('real NotesRemoteGateway soft-deletes a canonical Note through notes dispatch only', () async {
    final _GatewayTransport transport = _GatewayTransport();
    final SupabaseSyncExecutor executor = SupabaseSyncExecutor(
      tasksGateway: const TasksRemoteGateway(null),
      goalsGateway: const GoalsRemoteGateway(null),
      habitsGateway: const HabitsRemoteGateway(null),
      habitOccurrencesGateway: const HabitOccurrencesRemoteGateway(null),
      settingsGateway: const SettingsRemoteGateway(null),
      notesGateway: NotesRemoteGateway(
        _GatewayClient(_GatewayAuth('note-gateway-a'), transport),
      ),
    );
    final SyncApplyResult result = await executor.apply(SyncOperation(
      operationId: 'note-delete',
      tableName: 'notes',
      recordId: 'same-note',
      operationType: SyncOperationType.delete,
      payload: const <String, dynamic>{},
      userId: 'note-gateway-a',
      createdAtUtc: DateTime.utc(2026, 8, 15),
      retryCount: 0,
      nextRetryAtUtc: null,
      lastError: null,
    ));
    expect(result.ok, isTrue);
    final _GatewayRequest request = transport.requests.single;
    expect(request.method, 'PATCH');
    expect(request.uri.path, '/rest/v1/notes');
    expect(request.uri.queryParameters['id'], 'eq.same-note');
    expect(request.uri.queryParameters['user_id'], 'eq.note-gateway-a');
    final Map<String, dynamic> row = jsonDecode(request.body) as Map<String, dynamic>;
    expect(row['deleted_at'], isNotNull);
    expect(row['updated_at'], isNotNull);
  });
}
