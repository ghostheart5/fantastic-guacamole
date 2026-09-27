import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/services/sync_service.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

void main() {
  ProviderContainer containerFor(
    CloudRestoreOutcome outcome,
    Future<bool> Function() reconcile, {
    bool Function()? current,
  }) {
    final container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWith(
          (ref) => AccountStorageScope.authenticated(
            current?.call() == false ? 'other' : 'owner',
          ),
        ),
        cloudRestoreCapabilityProvider.overrideWithValue(true),
        cloudSyncPreferenceProvider.overrideWith(_OptedIn.new),
        supabaseClientProvider.overrideWithValue(_Client()),
        syncServiceProvider.overrideWithValue(_RestoreService(outcome)),
        restoredReminderReconciliationProvider.overrideWithValue(reconcile),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('restore waits for reminder reconciliation before completing', () async {
    final entered = Completer<void>();
    final release = Completer<bool>();
    final container = containerFor(CloudRestoreOutcome.restored, () {
      entered.complete();
      return release.future;
    });
    var completed = false;
    final pending = container.read(restoreFromCloudProvider.future);
    unawaited(pending.then((_) => completed = true));
    await entered.future;
    expect(completed, isFalse);
    expect(container.read(restoredSettingsRevisionProvider), 1);
    release.complete(true);
    expect(await pending, isTrue);
    expect(container.read(cloudRestoreWarningsProvider), isEmpty);
  });

  test('legacy cleanup and reminder failures both remain visible', () async {
    final container = containerFor(
      CloudRestoreOutcome.restoredLegacyCleanupPending,
      () async => false,
    );
    expect(await container.read(restoreFromCloudProvider.future), isTrue);
    expect(container.read(cloudRestoreWarningsProvider), {
      CloudRestoreWarning.legacyCleanupPending,
      CloudRestoreWarning.remindersPending,
    });
  });

  test(
    'OS errors preserve restored data and report reminder attention',
    () async {
      final container = containerFor(
        CloudRestoreOutcome.restored,
        () async => throw StateError('test platform unavailable'),
      );
      expect(await container.read(restoreFromCloudProvider.future), isTrue);
      expect(container.read(cloudRestoreWarningsProvider), {
        CloudRestoreWarning.remindersPending,
      });
    },
  );

  test('failed restore never changes reminder schedules', () async {
    var calls = 0;
    final container = containerFor(
      CloudRestoreOutcome.recoveryKeyRequired,
      () async {
        calls++;
        return true;
      },
    );
    expect(await container.read(restoreFromCloudProvider.future), isFalse);
    expect(calls, 0);
    expect(container.read(restoredSettingsRevisionProvider), 0);
  });

  test(
    'account change during reminder reconciliation prevents success',
    () async {
      var current = true;
      final entered = Completer<void>();
      final release = Completer<bool>();
      final container = containerFor(CloudRestoreOutcome.restored, () {
        entered.complete();
        return release.future;
      }, current: () => current);
      final pending = container.read(restoreFromCloudProvider.future);
      await entered.future;
      current = false;
      container.invalidate(accountStorageScopeProvider);
      release.complete(true);
      expect(await pending, isFalse);
    },
  );
}

class _OptedIn extends CloudSyncPreferenceNotifier {
  @override
  Future<bool> build() async => true;
}

class _RestoreService implements SyncService {
  _RestoreService(this.outcome);
  final CloudRestoreOutcome outcome;
  @override
  Future<CloudRestoreOutcome> restoreFromCloud() async => outcome;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Client implements sb.SupabaseClient {
  @override
  final sb.GoTrueClient auth = _Auth();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements sb.GoTrueClient {
  @override
  final sb.User currentUser = const sb.User(
    id: 'owner',
    appMetadata: {},
    userMetadata: null,
    aud: 'authenticated',
    createdAt: '2026-09-27T00:00:00Z',
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
