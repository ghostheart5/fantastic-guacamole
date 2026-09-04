import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('device-global preferences are excluded from account cleanup', () {
    expect(
      AccountDataRegistry.accountPreferenceExactKeys.intersection(
        AccountDataRegistry.deviceGlobalPreferenceKeys,
      ),
      isEmpty,
    );
  });

  test('backup preferences are account-owned and exclude device globals', () {
    expect(
      AccountDataRegistry.accountPreferenceExactKeys.containsAll(
        AccountDataRegistry.accountPreferenceBackupKeys,
      ),
      isTrue,
    );
    expect(
      AccountDataRegistry.accountPreferenceBackupKeys.intersection(
        AccountDataRegistry.deviceGlobalPreferenceKeys,
      ),
      isEmpty,
    );
    expect(
      AccountDataRegistry.accountPreferenceBackupKeys,
      isNot(contains('settings')),
    );
  });

  test('person context is explicitly local-only in the backup manifest', () {
    final Map<String, dynamic> manifest = accountDataBackupManifest();

    expect(
      manifest['excludedDomains'] as List<dynamic>,
      contains('person_context'),
    );
    expect(
      manifest['includedDomains'] as List<dynamic>,
      isNot(contains('person_context')),
    );
  });

  test('portable manifest truthfully covers canonical local continuity', () {
    final Map<String, dynamic> manifest = accountDataBackupManifest();

    expect(manifest['manifestVersion'], 2);
    expect(manifest['backupKind'], 'portableLocal');
    expect(manifest['cloudRestoreIncluded'], isFalse);
    expect(
      manifest['includedDomains'] as List<dynamic>,
      containsAll(<String>[
        'tasks',
        'goals',
        'habits',
        'notes',
        'task_occurrences',
        'decision_outcomes',
      ]),
    );
    expect(
      manifest['cloudReplicatedDomains'] as List<dynamic>,
      contains('task_occurrences'),
    );
  });

  test('account notification keys are stable, opaque, and isolated', () {
    final String first = AccountDataRegistry.notificationSecureKeyFor(
      'account-a',
    );
    expect(first, AccountDataRegistry.notificationSecureKeyFor(' account-a '));
    expect(
      first,
      isNot(AccountDataRegistry.notificationSecureKeyFor('account-b')),
    );
    expect(first, startsWith('notification_entries_v2.'));
    expect(first, isNot(contains('account-a')));
  });

  test('departing owner inventory includes candidate scoped storage', () {
    final String namespace = AccountDataRegistry.accountNamespace('owner-a');
    final AccountDataCleanupPlan cleanupPlan =
        AccountDataRegistry.cleanupPlanFor('owner-a');

    expect(cleanupPlan.hiveBoxes, contains('task_occurrences_v2.$namespace'));
    expect(cleanupPlan.hiveBoxes, contains('tasks_box.$namespace'));
    expect(cleanupPlan.hiveBoxes, contains('goals_box.$namespace'));
    expect(cleanupPlan.hiveBoxes, contains('habits_box.$namespace'));
    expect(cleanupPlan.hiveBoxes, contains('daily_plans_box.$namespace'));
    expect(cleanupPlan.hiveBoxes, contains('projects_box.$namespace'));
    expect(cleanupPlan.hiveBoxes, contains('routines_box.$namespace'));
    expect(cleanupPlan.hiveBoxes, contains('subtasks_box.$namespace'));
    expect(cleanupPlan.hiveBoxes, contains('progression_box.$namespace'));
    expect(cleanupPlan.hiveBoxes, contains('offline_queue_box.$namespace'));
    expect(cleanupPlan.hiveBoxes, contains('profile_box.$namespace'));
    expect(
      cleanupPlan.sensitivePreferenceKeys,
      contains('governed_memories_v2.$namespace'),
    );
    expect(
      cleanupPlan.sensitivePreferenceKeys,
      contains('person_context_spine_v1.$namespace'),
    );
    expect(
      cleanupPlan.sensitivePreferenceKeys,
      contains('person_context_spine_v1_corrupt.$namespace'),
    );
    expect(
      cleanupPlan.secureKeyPrefixes,
      contains('si_engine_state_v2.$namespace.'),
    );
    expect(
      cleanupPlan.preferenceKeyPrefixes,
      contains('adaptive_guidance_v3.$namespace.'),
    );
    expect(
      cleanupPlan.preferenceKeyPrefixes,
      contains('chronospark.si_console.thread.v1.$namespace.corrupt.'),
    );
    expect(
      cleanupPlan.preferenceExactKeys,
      contains('chronospark.si_console.thread.v1.$namespace'),
    );
    for (final String key in AccountDataRegistry.reminderPreferenceKeys) {
      expect(
        cleanupPlan.preferenceExactKeys,
        contains('$key.$namespace'),
        reason: key,
      );
    }
    expect(cleanupPlan.preferenceExactKeys, contains('notes_v1.$namespace'));
    expect(cleanupPlan.hiveBoxes, isNot(contains('tasks_box')));
    expect(cleanupPlan.secureExactKeys, isNot(contains('identity_id')));
    expect(cleanupPlan.preferenceExactKeys, isNot(contains('notes_v1')));
    expect(
      cleanupPlan.preferenceExactKeys,
      contains('chronospark.decision_outcomes.v1.$namespace'),
    );
    final String telemetryConsentKey =
        AccountDataRegistry.telemetryConsentStorageKeyFor('owner-a');
    expect(
      cleanupPlan.preferenceExactKeys,
      containsAll(<String>{
        '$telemetryConsentKey.analytics',
        '$telemetryConsentKey.crash_reporting',
        '$telemetryConsentKey.schema_version',
        '$telemetryConsentKey.updated_at_utc',
      }),
    );
  });

  test('proven legacy owner inventory includes legacy and scoped storage', () {
    final String namespace = AccountDataRegistry.accountNamespace('owner-a');
    final AccountDataCleanupPlan cleanupPlan =
        AccountDataRegistry.cleanupPlanFor(
          'owner-a',
          includeLegacyOwnedData: true,
        );

    expect(
      cleanupPlan.hiveBoxes,
      containsAll(<String>{'tasks_box', 'tasks_box.$namespace'}),
    );
    expect(
      cleanupPlan.secureExactKeys,
      containsAll(<String>{'identity_id', 'learning_state_v2.$namespace'}),
    );
    expect(
      cleanupPlan.preferenceExactKeys,
      containsAll(<String>{'notes_v1', 'notes_v1.$namespace'}),
    );
    expect(
      cleanupPlan.secureKeyPrefixes,
      contains(AccountDataRegistry.pendingPurchaseOwnerSecureKeyPrefix),
    );
  });

  test('legacy cleanup plan preserves account-scoped prefix deletion', () {
    final AccountDataCleanupPlan cleanupPlan =
        AccountDataRegistry.cleanupPlanFor(null);

    expect(cleanupPlan.hiveBoxes, AccountDataRegistry.legacyAccountHiveBoxes);
    expect(cleanupPlan.secureKeyPrefixes, <String>{
      AccountDataRegistry.pendingPurchaseOwnerSecureKeyPrefix,
    });
    expect(cleanupPlan.preferenceKeyPrefixes, isEmpty);
  });
}
