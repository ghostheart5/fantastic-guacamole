import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/services/sync_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

void main() {
  group('SupabaseStorageCloudBackupGateway', () {
    test('fails closed without an authenticated user', () async {
      final sb.SupabaseClient client = _supabaseClient(
        MockClient((http.Request request) async {
          fail('Unauthenticated storage operations must not reach HTTP.');
        }),
      );
      final SupabaseStorageCloudBackupGateway gateway =
          SupabaseStorageCloudBackupGateway(
            client: client,
            expectedUserId: 'user-1',
          );

      expect(
        (await gateway.downloadBackup()).status,
        CloudBackupReadStatus.ownerMismatch,
      );
      expect(
        (await gateway.downloadTasks()).status,
        CloudBackupReadStatus.ownerMismatch,
      );
      expect(
        await gateway.uploadBackup(<String, dynamic>{'version': 3}),
        isFalse,
      );
      expect(
        await gateway.uploadTasks(<String, dynamic>{'tasks': <dynamic>[]}),
        isFalse,
      );
    });

    test(
      'scopes successful downloads and uploads to the signed-in user',
      () async {
        final List<http.Request> storageRequests = <http.Request>[];
        final MockClient httpClient = MockClient((http.Request request) async {
          if (request.url.path.endsWith('/auth/v1/token')) {
            return _authResponse();
          }
          if (request.url.path.startsWith('/storage/v1/object/')) {
            storageRequests.add(request);
            expect(request.headers['authorization'], 'Bearer access-token');
            if (request.method == 'GET') {
              expect(
                request.url.path,
                '/storage/v1/object/backup-bucket/user-1/backup/full_backup.json',
              );
              return http.Response.bytes(
                utf8.encode(jsonEncode(<String, dynamic>{'version': 3})),
                200,
                headers: <String, String>{
                  'content-type': 'application/octet-stream',
                },
              );
            }
            expect(request.method, 'POST');
            expect(
              request.url.path,
              '/storage/v1/object/backup-bucket/user-1/backup/tasks_backup.json',
            );
            expect(
              utf8.decode(request.bodyBytes),
              contains(jsonEncode(<String, dynamic>{'tasks': <dynamic>[]})),
            );
            return http.Response(
              jsonEncode(<String, dynamic>{'Key': request.url.path}),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }
          fail('Unexpected request: ${request.method} ${request.url}');
        });
        final sb.SupabaseClient client = _supabaseClient(httpClient);
        await client.auth.signInWithPassword(
          email: 'sync@chronospark.app',
          password: 'correct-pass',
        );
        final SupabaseStorageCloudBackupGateway gateway =
            SupabaseStorageCloudBackupGateway(
              client: client,
              expectedUserId: 'user-1',
              bucket: 'backup-bucket',
            );

        final CloudBackupReadResult read = await gateway.downloadBackup();
        expect(read.status, CloudBackupReadStatus.found);
        expect(read.payload, <String, dynamic>{'version': 3});
        expect(
          await gateway.uploadTasks(<String, dynamic>{'tasks': <dynamic>[]}),
          isTrue,
        );
        expect(storageRequests, hasLength(2));
      },
    );

    test(
      'returns safe values for malformed and failed storage responses',
      () async {
        int downloadCalls = 0;
        final MockClient httpClient = MockClient((http.Request request) async {
          if (request.url.path.endsWith('/auth/v1/token')) {
            return _authResponse();
          }
          if (request.url.path.startsWith('/storage/v1/object/')) {
            if (request.method == 'POST') {
              return http.Response(
                jsonEncode(<String, dynamic>{'message': 'upload unavailable'}),
                503,
                headers: <String, String>{'content-type': 'application/json'},
              );
            }
            downloadCalls += 1;
            switch (downloadCalls) {
              case 1:
                return http.Response.bytes(
                  utf8.encode('["not-a-map"]'),
                  200,
                  headers: <String, String>{
                    'content-type': 'application/octet-stream',
                  },
                );
              case 2:
                return http.Response(
                  jsonEncode(<String, dynamic>{'message': 'not found'}),
                  404,
                  headers: <String, String>{'content-type': 'application/json'},
                );
              case 3:
                return http.Response(
                  jsonEncode(<String, dynamic>{
                    'message': 'backend unavailable',
                  }),
                  503,
                  headers: <String, String>{'content-type': 'application/json'},
                );
              default:
                throw StateError('transport failed');
            }
          }
          fail('Unexpected request: ${request.method} ${request.url}');
        });
        final sb.SupabaseClient client = _supabaseClient(httpClient);
        await client.auth.signInWithPassword(
          email: 'sync@chronospark.app',
          password: 'correct-pass',
        );
        final SupabaseStorageCloudBackupGateway gateway =
            SupabaseStorageCloudBackupGateway(
              client: client,
              expectedUserId: 'user-1',
            );

        await Logger.withMutedErrors(() async {
          expect(
            (await gateway.downloadBackup()).status,
            CloudBackupReadStatus.malformed,
          );
          expect(
            (await gateway.downloadTasks()).status,
            CloudBackupReadStatus.notFound,
          );
          expect(
            (await gateway.downloadBackup()).status,
            CloudBackupReadStatus.unavailable,
          );
          expect(
            (await gateway.downloadTasks()).status,
            CloudBackupReadStatus.unavailable,
          );
          expect(
            await gateway.uploadBackup(<String, dynamic>{'version': 3}),
            isFalse,
          );
        });
        expect(downloadCalls, 4);
      },
    );

    test('failed uploads do not log the account-scoped object path', () async {
      final MockClient httpClient = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/auth/v1/token')) {
          return _authResponse();
        }
        if (request.method == 'POST' &&
            request.url.path.startsWith('/storage/v1/object/')) {
          return http.Response(
            jsonEncode(<String, dynamic>{'message': 'upload unavailable'}),
            503,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        fail('Unexpected request: ${request.method} ${request.url}');
      });
      final sb.SupabaseClient client = _supabaseClient(httpClient);
      await client.auth.signInWithPassword(
        email: 'sync@chronospark.app',
        password: 'correct-pass',
      );
      final SupabaseStorageCloudBackupGateway gateway =
          SupabaseStorageCloudBackupGateway(
            client: client,
            expectedUserId: 'user-1',
          );
      final DebugPrintCallback originalDebugPrint = debugPrint;
      final List<String> output = <String>[];
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) output.add(message);
      };
      try {
        expect(
          await gateway.uploadBackup(<String, dynamic>{'version': 3}),
          isFalse,
        );
      } finally {
        debugPrint = originalDebugPrint;
      }

      final String logged = output.join('\n');
      expect(logged, contains('Supabase cloud backup upload failed'));
      expect(logged, isNot(contains('user-1')));
      expect(logged, isNot(contains('full_backup.json')));
    });

    test('download failures do not log raw provider details', () async {
      final MockClient httpClient = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/auth/v1/token')) {
          return _authResponse();
        }
        if (request.method == 'GET' &&
            request.url.path.startsWith('/storage/v1/object/')) {
          throw StateError(
            'user-1/backup/full_backup.json Bearer exposed-token',
          );
        }
        fail('Unexpected request: ${request.method} ${request.url}');
      });
      final sb.SupabaseClient client = _supabaseClient(httpClient);
      await client.auth.signInWithPassword(
        email: 'sync@chronospark.app',
        password: 'correct-pass',
      );
      final SupabaseStorageCloudBackupGateway gateway =
          SupabaseStorageCloudBackupGateway(
            client: client,
            expectedUserId: 'user-1',
          );
      final DebugPrintCallback originalDebugPrint = debugPrint;
      final List<String> output = <String>[];
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) output.add(message);
      };
      try {
        expect(
          (await gateway.downloadBackup()).status,
          CloudBackupReadStatus.unavailable,
        );
      } finally {
        debugPrint = originalDebugPrint;
      }

      final String logged = output.join('\n');
      expect(logged, contains('Supabase cloud backup download failed'));
      expect(logged, isNot(contains('user-1')));
      expect(logged, isNot(contains('full_backup.json')));
      expect(logged, isNot(contains('exposed-token')));
    });

    test(
      'fails closed when the immutable owner no longer matches auth',
      () async {
        final sb.SupabaseClient client = _supabaseClient(
          MockClient((http.Request request) async {
            if (request.url.path.endsWith('/auth/v1/token')) {
              return _authResponse();
            }
            fail('Mismatched-owner storage must not reach HTTP.');
          }),
        );
        await client.auth.signInWithPassword(
          email: 'sync@chronospark.app',
          password: 'correct-pass',
        );
        final SupabaseStorageCloudBackupGateway gateway =
            SupabaseStorageCloudBackupGateway(
              client: client,
              expectedUserId: 'different-user',
            );

        expect(
          (await gateway.downloadBackup()).status,
          CloudBackupReadStatus.ownerMismatch,
        );
        expect(
          await gateway.uploadBackup(<String, dynamic>{'version': 3}),
          isFalse,
        );
      },
    );
  });

  group('SupabaseCasCloudBackupGateway', () {
    test(
      'reads a versioned snapshot and advances the matching revision',
      () async {
        int databaseCalls = 0;
        final List<String> observedRequests = <String>[];
        final MockClient httpClient = MockClient((http.Request request) async {
          observedRequests.add('${request.method} ${request.url}');
          if (request.url.path.endsWith('/auth/v1/token')) {
            return _authResponse();
          }
          if (request.url.path == '/rest/v1/cloud_backup_snapshots') {
            databaseCalls += 1;
            if (request.method == 'GET') {
              return http.Response(
                jsonEncode(<Map<String, dynamic>>[
                  <String, dynamic>{
                    'revision': 4,
                    'payload': <String, dynamic>{'version': '3.0.0'},
                  },
                ]),
                200,
                headers: <String, String>{'content-type': 'application/json'},
                request: request,
              );
            }
            expect(request.method, 'PATCH');
            expect(request.url.query, contains('user_id=eq.user-1'));
            expect(request.url.query, contains('revision=eq.4'));
            return http.Response(
              jsonEncode(<Map<String, dynamic>>[
                <String, dynamic>{'revision': 5},
              ]),
              200,
              headers: <String, String>{'content-type': 'application/json'},
              request: request,
            );
          }
          fail('Unexpected request: ${request.method} ${request.url}');
        });
        final sb.SupabaseClient client = _supabaseClient(httpClient);
        await client.auth.signInWithPassword(
          email: 'sync@chronospark.app',
          password: 'correct-pass',
        );
        final SupabaseCasCloudBackupGateway gateway =
            SupabaseCasCloudBackupGateway(
              client: client,
              expectedUserId: 'user-1',
            );

        final CloudBackupReadResult read = await gateway.downloadBackup();
        expect(
          read.status,
          CloudBackupReadStatus.found,
          reason: observedRequests.join('\n'),
        );
        expect(read.revision, 4);
        expect(
          await gateway.compareAndSwapBackup(<String, dynamic>{
            'version': '3.0.0',
          }, expectedRevision: 4),
          isA<CloudBackupWriteResult>()
              .having(
                (CloudBackupWriteResult result) => result.status,
                'status',
                CloudBackupWriteStatus.written,
              )
              .having(
                (CloudBackupWriteResult result) => result.revision,
                'revision',
                5,
              ),
        );
        expect(databaseCalls, 2);
      },
    );

    test('returns conflict when a stale revision updates no row', () async {
      int databaseCalls = 0;
      final List<String> observedRequests = <String>[];
      final MockClient httpClient = MockClient((http.Request request) async {
        observedRequests.add('${request.method} ${request.url}');
        if (request.url.path.endsWith('/auth/v1/token')) return _authResponse();
        if (request.url.path == '/rest/v1/cloud_backup_snapshots') {
          databaseCalls += 1;
          if (request.method == 'PATCH') {
            return http.Response(
              '[]',
              200,
              headers: <String, String>{'content-type': 'application/json'},
              request: request,
            );
          }
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[
              <String, dynamic>{
                'revision': 5,
                'payload': <String, dynamic>{'version': '3.0.0'},
              },
            ]),
            200,
            headers: <String, String>{'content-type': 'application/json'},
            request: request,
          );
        }
        fail('Unexpected request: ${request.method} ${request.url}');
      });
      final sb.SupabaseClient client = _supabaseClient(httpClient);
      await client.auth.signInWithPassword(
        email: 'sync@chronospark.app',
        password: 'correct-pass',
      );
      final SupabaseCasCloudBackupGateway gateway =
          SupabaseCasCloudBackupGateway(
            client: client,
            expectedUserId: 'user-1',
          );

      final CloudBackupWriteResult result = await gateway.compareAndSwapBackup(
        <String, dynamic>{'version': '3.0.0'},
        expectedRevision: 4,
      );

      expect(
        result.status,
        CloudBackupWriteStatus.conflict,
        reason: observedRequests.join('\n'),
      );
      expect(result.revision, 5);
      expect(databaseCalls, 2);
    });

    test('migrates a legacy storage object through revision zero', () async {
      final MockClient httpClient = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/auth/v1/token')) {
          return _authResponse();
        }
        if (request.url.path == '/rest/v1/cloud_backup_snapshots') {
          if (request.method == 'GET') {
            return http.Response(
              '[]',
              200,
              headers: <String, String>{'content-type': 'application/json'},
              request: request,
            );
          }
          expect(request.method, 'POST');
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[
              <String, dynamic>{'revision': 1},
            ]),
            201,
            headers: <String, String>{'content-type': 'application/json'},
            request: request,
          );
        }
        if (request.method == 'GET' &&
            request.url.path.endsWith(
              '/storage/v1/object/chronospark-sync/user-1/backup/full_backup.json',
            )) {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode(<String, dynamic>{
                'version': '3.0.0',
                'tasks': <dynamic>[],
              }),
            ),
            200,
            headers: <String, String>{
              'content-type': 'application/octet-stream',
            },
            request: request,
          );
        }
        fail('Unexpected request: ${request.method} ${request.url}');
      });
      final sb.SupabaseClient client = _supabaseClient(httpClient);
      await client.auth.signInWithPassword(
        email: 'sync@chronospark.app',
        password: 'correct-pass',
      );
      final SupabaseCasCloudBackupGateway gateway =
          SupabaseCasCloudBackupGateway(
            client: client,
            expectedUserId: 'user-1',
          );

      final CloudBackupReadResult legacy = await gateway.downloadBackup();
      expect(legacy.status, CloudBackupReadStatus.found);
      expect(legacy.revision, 0);
      final Map<String, dynamic> legacyPayload =
          legacy.payload ?? fail('Legacy payload must be present.');
      final CloudBackupWriteResult migrated = await gateway
          .compareAndSwapBackup(legacyPayload, expectedRevision: 0);
      expect(migrated.status, CloudBackupWriteStatus.written);
      expect(migrated.revision, 1);
    });

    test('rejects oversized snapshots before any database write', () async {
      int backupRequests = 0;
      final MockClient httpClient = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/auth/v1/token')) {
          return _authResponse();
        }
        backupRequests += 1;
        fail('Oversized backup reached the network: ${request.url}');
      });
      final sb.SupabaseClient client = _supabaseClient(httpClient);
      await client.auth.signInWithPassword(
        email: 'sync@chronospark.app',
        password: 'correct-pass',
      );
      final SupabaseCasCloudBackupGateway gateway =
          SupabaseCasCloudBackupGateway(
            client: client,
            expectedUserId: 'user-1',
          );

      final CloudBackupWriteResult result = await gateway.compareAndSwapBackup(
        <String, dynamic>{
          'payload': 'x' * (SupabaseCasCloudBackupGateway.maxPayloadBytes + 1),
        },
        expectedRevision: 0,
      );

      expect(result.status, CloudBackupWriteStatus.malformed);
      expect(backupRequests, 0);
    });
  });
}

sb.SupabaseClient _supabaseClient(http.Client client) {
  return sb.SupabaseClient(
    'https://chronospark.example.com',
    'anon-key',
    httpClient: client,
    authOptions: const sb.AuthClientOptions(
      authFlowType: sb.AuthFlowType.implicit,
    ),
  );
}

http.Response _authResponse() {
  return http.Response(
    jsonEncode(<String, dynamic>{
      'access_token': 'access-token',
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': 'refresh-token',
      'user': <String, dynamic>{
        'id': 'user-1',
        'aud': 'authenticated',
        'email': 'sync@chronospark.app',
        'created_at': '2026-08-21T00:00:00.000Z',
        'email_confirmed_at': '2026-08-21T00:00:00.000Z',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
      },
    }),
    200,
    headers: <String, String>{'content-type': 'application/json'},
  );
}
