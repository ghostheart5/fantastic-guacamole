import 'dart:convert';
import 'dart:io';

import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
import 'package:fantastic_guacamole/data/services/backup_cipher.dart';
import 'package:fantastic_guacamole/data/services/backup_service.dart';
import 'package:fantastic_guacamole/data/services/sync_service.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

// Explicit live integration entry point; no _test suffix so offline discovery
// does not execute a network-dependent test or hide it as a skipped case.
// Real application services and real local Supabase; synthetic local stores.
void main() {
  test(
    'encrypted sync, recovery restore, offline retry and CAS isolation',
    () async {
      final String? base = Platform.environment['LOCAL_SUPABASE_URL'];
      final String? anon = Platform.environment['LOCAL_SUPABASE_ANON_KEY'];
      final String? service =
          Platform.environment['LOCAL_SUPABASE_SERVICE_KEY'];
      expect(Platform.environment['AXIOMARA_DISPOSABLE_DB_GATE'], 'true');
      expect(base, 'http://127.0.0.1:54321');
      expect(anon, isNotEmpty);
      expect(service, isNotEmpty);
      final http.Client admin = http.Client();
      final _SwitchableClient network = _SwitchableClient();
      final sb.SupabaseClient client = sb.SupabaseClient(
        base!,
        anon!,
        httpClient: network,
        authOptions: const sb.AuthClientOptions(autoRefreshToken: false),
      );
      final String unique = DateTime.now().microsecondsSinceEpoch.toString();
      final String email = 'client-cloud-$unique@example.invalid';
      final String password = 'Synthetic-cloud-$unique-Only!';
      String? createdId;
      Directory? hiveDirectory;
      try {
        final http.Response created = await admin.post(
          Uri.parse('$base/auth/v1/admin/users'),
          headers: <String, String>{
            'apikey': service!,
            'Authorization': 'Bearer $service',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, Object>{
            'email': email,
            'password': password,
            'email_confirm': true,
          }),
        );
        expect(
          created.statusCode,
          200,
          reason: 'Create synthetic Auth fixture',
        );
        createdId =
            (jsonDecode(created.body) as Map<String, dynamic>)['id'] as String;
        await client.auth.signInWithPassword(email: email, password: password);
        expect(client.auth.currentUser?.id, createdId);
        final SupabaseCasCloudBackupGateway gateway =
            SupabaseCasCloudBackupGateway(
              client: client,
              expectedUserId: createdId,
            );
        SharedPreferences.setMockInitialValues(<String, Object>{});
        hiveDirectory = await Directory.systemTemp.createTemp(
          'axiomara_cloud_acceptance_',
        );
        Hive.init(hiveDirectory.path);
        final _Tasks tasks = _Tasks();
        final BackupService backup = BackupService(
          taskRepository: tasks,
          profileStorage: HiveStorage<String>(
            'synthetic_profile',
            hive: _HiveStore(),
          ),
          prefs: SharedPrefsStorage(await SharedPreferences.getInstance()),
        );
        final SecureStore keys = SecureStore(
          backend: InMemorySecureStoreBackend(),
        );
        String? account = createdId;
        SyncService syncWith(SecureStore store) => SyncService(
          backup: backup,
          gateway: gateway,
          secureStore: store,
          expectedAccountId: createdId,
          currentAccountId: () => account,
          syncEnabled: true,
          restoreEnabled: true,
        );
        final SyncService sync = syncWith(keys);
        await tasks.saveTask(
          TaskEntity(
            id: 'synthetic-task',
            title: 'Private synthetic restore marker',
            createdAt: DateTime.utc(2026, 9, 26),
          ),
        );
        expect(await sync.syncDeltaOutcome(), CloudSyncOutcome.synced);
        final CloudBackupReadResult initial = await gateway.downloadBackup();
        expect(initial.revision, 1);
        expect(initial.payload?['format'], 'chronospark_backup_aes256_gcm_v2');
        expect(
          jsonEncode(initial.payload),
          isNot(contains('Private synthetic restore marker')),
        );

        tasks.values.clear();
        final SecureStore replacementKeys = SecureStore(
          backend: InMemorySecureStoreBackend(),
        );
        final SyncService replacement = syncWith(replacementKeys);
        expect(
          await replacement.restoreFromCloud(),
          CloudRestoreOutcome.recoveryKeyRequired,
        );
        expect(tasks.values, isEmpty);
        // The recovery key stays in memory and is never printed or uploaded.
        await BackupCipher(
          replacementKeys,
          accountId: createdId,
        ).importRecoveryKey(
          await BackupCipher(keys, accountId: createdId).exportRecoveryKey(),
        );
        expect(
          await replacement.restoreFromCloud(),
          CloudRestoreOutcome.restored,
        );
        expect(
          (await tasks.getTaskById('synthetic-task'))?.title,
          'Private synthetic restore marker',
        );

        final List<CloudBackupWriteResult> competing = await Future.wait(
          <Future<CloudBackupWriteResult>>[
            gateway.compareAndSwapBackup(initial.payload!, expectedRevision: 1),
            gateway.compareAndSwapBackup(initial.payload!, expectedRevision: 1),
          ],
        );
        expect(
          competing.where(
            (CloudBackupWriteResult result) =>
                result.status == CloudBackupWriteStatus.written,
          ),
          hasLength(1),
        );
        expect(
          competing.where(
            (CloudBackupWriteResult result) =>
                result.status == CloudBackupWriteStatus.conflict,
          ),
          hasLength(1),
        );
        expect((await gateway.downloadBackup()).revision, 2);

        await tasks.saveTask(
          TaskEntity(
            id: 'offline-task',
            title: 'Synthetic offline edit',
            createdAt: DateTime.utc(2026, 9, 26),
          ),
        );
        network.offline = true;
        expect(await sync.syncDeltaOutcome(), CloudSyncOutcome.unavailable);
        expect(await tasks.getTaskById('offline-task'), isNotNull);
        network.offline = false;
        expect(await sync.syncDeltaOutcome(), CloudSyncOutcome.synced);
        tasks.values.clear();
        expect(
          await replacement.restoreFromCloud(),
          CloudRestoreOutcome.restored,
        );
        expect(tasks.values.keys.toSet(), <String>{
          'synthetic-task',
          'offline-task',
        });

        account = 'different-account';
        expect(await sync.syncDeltaOutcome(), CloudSyncOutcome.accountChanged);
        expect(
          await sync.restoreFromCloud(),
          CloudRestoreOutcome.accountChanged,
        );
        final SupabaseCasCloudBackupGateway wrongOwner =
            SupabaseCasCloudBackupGateway(
              client: client,
              expectedUserId: 'different-account',
            );
        expect(
          (await wrongOwner.downloadBackup()).status,
          CloudBackupReadStatus.ownerMismatch,
        );
      } finally {
        network.offline = false;
        await client.dispose();
        network.close();
        if (createdId != null) {
          final http.Response removed = await admin.delete(
            Uri.parse('$base/auth/v1/admin/users/$createdId'),
            headers: <String, String>{
              'apikey': service!,
              'Authorization': 'Bearer $service',
            },
          );
          expect(
            <int>{200, 204, 404},
            contains(removed.statusCode),
            reason: 'Remove only this run synthetic account',
          );
        }
        admin.close();
        await Hive.close();
        if (hiveDirectory != null) await hiveDirectory.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _SwitchableClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  bool offline = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.url.host != '127.0.0.1' || request.url.port != 54321) {
      throw StateError(
        'Integration network must remain on disposable loopback',
      );
    }
    if (offline) throw const SocketException('Synthetic offline interval');
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

class _Tasks implements ITaskRepository {
  final Map<String, TaskEntity> values = <String, TaskEntity>{};
  @override
  Future<void> deleteTask(String id) async => values.remove(id);
  @override
  Future<List<TaskEntity>> getAllTasks() async => values.values.toList();
  @override
  Future<TaskEntity?> getTaskById(String id) async => values[id];
  @override
  Future<void> saveTask(TaskEntity task) async => values[task.id] = task;
}

class _HiveStore implements HiveStore {
  @override
  Box<T> box<T>(String key) => Hive.box<T>(key);
  @override
  Future<void> clearBox(String key) async =>
      (await openBox<String>(key)).clear();
  @override
  Future<void> closeBox(String key) async {
    if (Hive.isBoxOpen(key)) await Hive.box<String>(key).close();
  }

  @override
  Future<void> init() async {}
  @override
  bool isBoxOpen(String key) => Hive.isBoxOpen(key);
  @override
  Future<Box<T>> openBox<T>(String key) async =>
      Hive.isBoxOpen(key) ? Hive.box<T>(key) : await Hive.openBox<T>(key);
}
