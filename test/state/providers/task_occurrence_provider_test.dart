import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/services/task_occurrence_cloud_replica.dart';
import 'package:fantastic_guacamole/state/providers/task_occurrence_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

void main() {
  test('contained builds never provide a task-occurrence cloud replica', () {
    expect(Env.enableCloudSync, isFalse);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        supabaseClientProvider.overrideWithValue(
          _FakeSupabaseClient(
            _FakeGoTrueClient(
              const sb.User(
                id: 'account-a',
                appMetadata: <String, dynamic>{},
                userMetadata: null,
                aud: 'authenticated',
                createdAt: '2026-08-30T00:00:00.000Z',
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final TaskOccurrenceCloudReplica? replica = container.read(
      taskOccurrenceCloudReplicaProvider,
    );

    expect(replica, isNull);
  });
}

class _FakeSupabaseClient implements sb.SupabaseClient {
  _FakeSupabaseClient(this.auth);

  @override
  final sb.GoTrueClient auth;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGoTrueClient implements sb.GoTrueClient {
  _FakeGoTrueClient(this.currentUser);

  @override
  final sb.User? currentUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
