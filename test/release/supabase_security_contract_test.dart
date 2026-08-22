import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  test('Supabase security migrations retain authenticated ownership controls', () {
    final String creditMigration = SourceTestUtils.readText(
      File(
        'supabase/migrations/20260804120000_harden_monetization_credit_rpc.sql',
      ),
    );
    final String coreMigration = SourceTestUtils.readText(
      File(
        'supabase/migrations/20260804130000_create_core_sync_tables_with_rls.sql',
      ),
    );
    final String metricsMigration = SourceTestUtils.readText(
      File(
        'supabase/migrations/20260804140000_harden_metrics_and_profile_provisioning.sql',
      ),
    );
    final String aiMigration = SourceTestUtils.readText(
      File('supabase/migrations/20260804150000_harden_ai_proxy_rate_limit.sql'),
    );
    final String verifyRateLimitMigration = SourceTestUtils.readText(
      File(
        'supabase/migrations/20260809120000_add_monetization_verify_rate_limit.sql',
      ),
    );

    expect(creditMigration, contains('security definer'));
    expect(creditMigration, contains('current_user_id uuid := auth.uid()'));
    expect(creditMigration, contains('credit_amount <= 0'));
    expect(
      creditMigration,
      contains('revoke all on function public.ensure_monetization_wallet'),
    );
    expect(coreMigration, contains('primary key (user_id, id)'));
    expect(
      coreMigration,
      contains('with check ((select auth.uid()) = user_id)'),
    );
    expect(metricsMigration, contains('ensure_profile_for_current_user'));
    expect(metricsMigration, contains('from public, anon, authenticated'));
    expect(aiMigration, contains('consume_ai_proxy_rate_limit'));
    expect(
      verifyRateLimitMigration,
      contains('consume_monetization_verify_rate_limit'),
    );
  });

  test('Supabase clients do not retain legacy credit fallbacks', () {
    final String repository = SourceTestUtils.readText(
      File(
        'lib/features/monetization/data/repositories/ai_credit_repository.dart',
      ),
    );
    expect(repository.contains('ai_credit_wallets'), isFalse);
    expect(repository.contains('ai_credit_transactions'), isFalse);
    expect(repository.contains('ai_credit_purchases'), isFalse);
  });

  test('recovered task and goal links preserve account-scoped identity', () {
    final String recoveryMigration = SourceTestUtils.readText(
      File(
        'supabase/migrations/'
        '20260809221655_recover_hosted_public_tables.sql',
      ),
    );

    for (final String identifierColumn in <String>[
      '"linked_task_id" text',
      '"linked_goal_id" text',
      '"goal_id" text not null',
      '"task_id" text not null',
    ]) {
      expect(recoveryMigration, contains(identifierColumn));
    }

    for (final String accountScopedReference in <String>[
      'FOREIGN KEY (user_id, linked_goal_id) '
          'REFERENCES goals(user_id, id) ON DELETE SET NULL (linked_goal_id)',
      'FOREIGN KEY (user_id, linked_task_id) '
          'REFERENCES tasks(user_id, id) ON DELETE SET NULL (linked_task_id)',
      'FOREIGN KEY (user_id, goal_id) '
          'REFERENCES goals(user_id, id) ON DELETE CASCADE',
      'FOREIGN KEY (user_id, task_id) '
          'REFERENCES tasks(user_id, id) ON DELETE CASCADE',
    ]) {
      expect(recoveryMigration, contains(accountScopedReference));
    }

    expect(recoveryMigration, isNot(contains('REFERENCES goals(id)')));
    expect(recoveryMigration, isNot(contains('REFERENCES tasks(id)')));
  });

  test('Edge function validators and database regression suites are tracked', () {
    final File subscriptionTest = File(
      'supabase/functions/monetization-verify/subscription_verification_test.ts',
    );
    final File aiProxyTest = File(
      'supabase/functions/ai-proxy/ai_proxy_request_validation_test.ts',
    );
    final File creditTest = File(
      'supabase/tests/monetization_credit_rpc_test.sql',
    );
    final File rlsTest = File('supabase/tests/core_sync_rls_test.sql');
    final File rateLimitTest = File(
      'supabase/tests/ai_proxy_rate_limit_test.sql',
    );
    final File verifyRateLimitTest = File(
      'supabase/tests/monetization_verify_rate_limit_test.sql',
    );

    expect(subscriptionTest.existsSync(), isTrue);
    expect(aiProxyTest.existsSync(), isTrue);
    expect(
      SourceTestUtils.readText(subscriptionTest),
      contains('lower-tier token'),
    );
    expect(
      SourceTestUtils.readText(aiProxyTest),
      contains('rejects caller-authored system prompts'),
    );
    expect(
      SourceTestUtils.readText(creditTest),
      contains('negative credit consumption'),
    );
    expect(
      SourceTestUtils.readText(rlsTest),
      contains('storage cross-prefix upload is denied'),
    );
    expect(
      SourceTestUtils.readText(rateLimitTest),
      contains('next request is rejected'),
    );
    expect(verifyRateLimitTest.existsSync(), isTrue);
    expect(
      SourceTestUtils.readText(verifyRateLimitTest),
      contains('next verification request is rejected'),
    );
  });
}
