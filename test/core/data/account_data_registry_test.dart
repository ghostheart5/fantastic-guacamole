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
    expect(cleanupPlan.preferenceExactKeys, contains('notes_v1.$namespace'));
    expect(
      cleanupPlan.preferenceExactKeys,
      contains('chronospark.decision_outcomes.v1.$namespace'),
    );
  });

  test('legacy cleanup plan preserves account-scoped prefix deletion', () {
    final AccountDataCleanupPlan cleanupPlan =
        AccountDataRegistry.cleanupPlanFor(null);

    expect(cleanupPlan.hiveBoxes, AccountDataRegistry.legacyAccountHiveBoxes);
    expect(cleanupPlan.secureKeyPrefixes, isEmpty);
    expect(cleanupPlan.preferenceKeyPrefixes, isEmpty);
  });
}
