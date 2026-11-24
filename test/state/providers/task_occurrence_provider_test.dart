import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
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
  group('cloud backup preference gate', () {
    sb.User user(String id) => sb.User(
      id: id,
      appMetadata: const <String, dynamic>{},
      userMetadata: null,
      aud: 'authenticated',
      createdAt: '2026-08-30T00:00:00.000Z',
    );

    ProviderContainer build(_PrefNotifier notifier) {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          cloudSyncCapabilityProvider.overrideWithValue(true),
          cloudSyncPreferenceProvider.overrideWith(() => notifier),
          supabaseClientProvider.overrideWithValue(
            _FakeSupabaseClient(_FakeGoTrueClient(user('account-a'))),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('provides no replica while Cloud Backup is off', () async {
      final ProviderContainer container = build(_PrefNotifier(false));
      await container.read(cloudSyncPreferenceProvider.future);

      expect(container.read(taskOccurrenceCloudReplicaProvider), isNull);
    });

    test('provides no replica while the preference is still loading', () {
      final ProviderContainer container = build(_PrefNotifier(false));

      expect(container.read(taskOccurrenceCloudReplicaProvider), isNull);
    });

    test(
      'provides a replica once Cloud Backup is on and drops it again',
      () async {
        final ProviderContainer container = build(_PrefNotifier(false));
        await container.read(cloudSyncPreferenceProvider.future);
        expect(container.read(taskOccurrenceCloudReplicaProvider), isNull);

        await container
            .read(cloudSyncPreferenceProvider.notifier)
            .setEnabled(true);
        expect(
          container.read(taskOccurrenceCloudReplicaProvider),
          isA<SupabaseTaskOccurrenceCloudReplica>(),
        );

        await container
            .read(cloudSyncPreferenceProvider.notifier)
            .setEnabled(false);
        expect(container.read(taskOccurrenceCloudReplicaProvider), isNull);
      },
    );
  });
}

class _PrefNotifier extends CloudSyncPreferenceNotifier {
  _PrefNotifier(this.initial);
  final bool initial;

  @override
  Future<bool> build() async => initial;

  @override
  Future<void> setEnabled(bool enabled) async {
    state = AsyncData<bool>(enabled);
  }
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
