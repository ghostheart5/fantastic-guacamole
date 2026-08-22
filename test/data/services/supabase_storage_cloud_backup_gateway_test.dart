import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/services/sync_service.dart';
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
          SupabaseStorageCloudBackupGateway(client: client);

      expect(await gateway.downloadBackup(), isEmpty);
      expect(await gateway.downloadTasks(), isEmpty);
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
              bucket: 'backup-bucket',
            );

        expect(await gateway.downloadBackup(), <String, dynamic>{'version': 3});
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
            SupabaseStorageCloudBackupGateway(client: client);

        await Logger.withMutedErrors(() async {
          expect(await gateway.downloadBackup(), isEmpty);
          expect(await gateway.downloadTasks(), isEmpty);
          expect(await gateway.downloadBackup(), isEmpty);
          expect(await gateway.downloadTasks(), isEmpty);
          expect(
            await gateway.uploadBackup(<String, dynamic>{'version': 3}),
            isFalse,
          );
        });
        expect(downloadCalls, 4);
      },
    );
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
