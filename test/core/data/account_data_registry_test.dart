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
    expect(
      cleanupPlan.sensitivePreferenceKeys,
      contains('governed_memories_v2.$namespace'),
    );
    expect(
      cleanupPlan.secureKeyPrefixes,
      contains('si_engine_state_v2.$namespace.'),
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
