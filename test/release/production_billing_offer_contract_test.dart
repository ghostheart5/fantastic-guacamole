import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('server allowance grants match plans and paid billing causes', () {
    final String fallback = File(
      'lib/data/repositories/paywall_repository.dart',
    ).readAsStringSync();
    final String googlePlay = File(
      'lib/data/repositories/google_play_paywall_repository.dart',
    ).readAsStringSync();
    final String migration = File(
      'supabase/migrations/20260830152232_harden_phase8_billing_authority.sql',
    ).readAsStringSync();

    for (final String repository in <String>[fallback, googlePlay]) {
      expect(repository, contains('aiCreditsIncluded: 300'));
      expect(repository, contains('aiCreditsIncluded: 360'));
    }
    expect(migration, contains("when 'premium_monthly' then 300"));
    expect(migration, contains("when 'premium_yearly' then 360"));
    expect(migration, contains("grant_cause = 'initial_activation'"));
    expect(migration, contains("grant_cause = 'rtdn_renewal'"));
    expect(migration, contains("grant_cause = 'resubscription_activation'"));
    expect(migration, contains("grant_cause = 'recovery_activation'"));
    expect(migration, contains('v_is_late_lapsed_resubscription'));
    expect(migration, contains('v_is_same_token_recovery'));
    expect(migration, contains('v_is_hold_repurchase'));
    expect(migration, contains("'subscription_resubscribed_late_expiry'"));
    expect(migration, contains('p_notification_type <> 2'));
    expect(migration, contains('p_notification_type <> 4'));
    expect(migration, isNot(contains("interval '1 month'")));
  });

  test('active authority blocks a second Google Play purchase', () {
    final String repository = File(
      'lib/data/repositories/google_play_paywall_repository.dart',
    ).readAsStringSync();
    final String page = File(
      'lib/features/paywall/ui/paywall_page.dart',
    ).readAsStringSync();

    expect(repository, contains('if (_effectiveStateForCurrentUser.isActive)'));
    expect(
      repository.indexOf('if (_effectiveStateForCurrentUser.isActive)'),
      lessThan(repository.indexOf('queryProductDetails(<String>{productId})')),
    );
    expect(repository, contains('Manage plan changes in Google Play.'));
    expect(page, contains('!hasActiveSubscription'));
    expect(page, contains('Current subscription active'));
  });

  test(
    'Phase 8 database contract covers recovery and free-only reattachment',
    () {
      final String migration = File(
        'supabase/migrations/20260830152232_harden_phase8_billing_authority.sql',
      ).readAsStringSync();
      final String pgTap = File(
        'supabase/tests/phase8_billing_authority.test.sql',
      ).readAsStringSync();
      final RegExp assertion = RegExp(
        r'^select (?:has_table|is|ok|results_eq|throws_ok)\(',
        multiLine: true,
      );

      expect(pgTap, contains('select plan(140);'));
      expect(assertion.allMatches(pgTap), hasLength(140));
      expect(pgTap, contains('phase8:rtdn:hold-recovered'));
      expect(pgTap, contains('phase8:rtdn:hold-repurchase-purchased'));
      expect(pgTap, contains('phase8-recreated-free-request'));
      expect(migration, contains('v_bootstrap_is_free_only'));
      expect(migration, contains("type not in ("));
      expect(migration, contains("state = 'reserved'"));
      expect(migration, contains("'principal_reattached'"));
    },
  );

  test(
    'RTDN trusts verified Play authority instead of optional payload fields',
    () {
      final String handler = File(
        'supabase/functions/google-play-rtdn/index.ts',
      ).readAsStringSync();
      final String logic = File(
        'supabase/functions/_shared/google_play_rtdn.ts',
      ).readAsStringSync();

      expect(handler, contains('selectSubscriptionAuthorityLine('));
      expect(handler, isNot(contains('subscription.subscriptionId')));
      expect(handler, contains('out_of_app_resubscribe'));
      expect(logic, contains('result.billingPrincipalId'));
      expect(logic, contains('result.userId !== null'));
    },
  );

  test('visible paywall copy makes only supported billing claims', () {
    final String googlePlay = File(
      'lib/data/repositories/google_play_paywall_repository.dart',
    ).readAsStringSync();
    final String provider = File(
      'lib/state/providers/paywall_provider.dart',
    ).readAsStringSync();
    final String page = File(
      'lib/features/paywall/ui/paywall_page.dart',
    ).readAsStringSync();
    final String visibleCopy = '$provider\n$page';
    final String lowerCopy = visibleCopy.toLowerCase();

    for (final String unsupported in <String>[
      'premium planning',
      'deeper memory',
      'memory and signals',
      'priority smart',
      'priority ai',
      'limited voice',
      'advanced agents',
      'advanced tools',
      'unlimited',
      'billing discount',
      'best value',
      'cancel anytime',
      'hidden fees',
      'preview premium',
      'unlock ai credits',
      'unlock smart credits',
      'credits per month',
    ]) {
      expect(
        lowerCopy,
        isNot(contains(unsupported)),
        reason: 'Unsupported offer claim remains: $unsupported',
      );
    }

    expect(
      page,
      contains(
        'Credits after a verified purchase or paid renewal: \${plan.aiCreditsIncluded}',
      ),
    );
    expect(page, contains('plan.priceLabel'));
    expect(page, isNot(contains('plan.benefits')));
    expect(
      visibleCopy,
      contains('Google Play confirms billing frequency and renewal terms'),
    );
    expect(googlePlay, contains('priceLabel: detail?.price'));
    expect(googlePlay, contains("priceLabel: 'Price unavailable'"));
    expect(provider, isNot(contains('titleOverride')));
    expect(provider, isNot(contains('bodyOverride')));
    expect(visibleCopy, isNot(contains(r'$9.99')));
    expect(visibleCopy, isNot(contains(r'$89.99')));
  });

  test('paid plans are routed through the complete containment gate', () {
    final String containment = File(
      'lib/config/launch_containment.dart',
    ).readAsStringSync();
    final String env = File('lib/config/env.dart').readAsStringSync();
    final String repositories = File(
      'lib/data/di/repositories_providers.dart',
    ).readAsStringSync();
    final String provider = File(
      'lib/state/providers/paywall_provider.dart',
    ).readAsStringSync();
    final String page = File(
      'lib/features/paywall/ui/paywall_page.dart',
    ).readAsStringSync();

    expect(containment, contains('static const bool paidCreditPlansEnabled ='));
    for (final String requiredGate in <String>[
      'subscriptionsEnabled &&',
      'externalAiEnabled &&',
      'creditSpendingEnabled &&',
      'externalAiProviderRetentionVerified &&',
      'externalAiSafetyReviewApproved;',
    ]) {
      expect(containment, contains(requiredGate));
    }
    expect(env, contains('LaunchContainment.paidCreditPlansEnabled'));
    expect(repositories, contains('if (!Env.paidCreditPlansEnabled)'));
    expect(
      provider,
      contains('if (!LaunchContainment.paidCreditPlansEnabled)'),
    );
    expect(
      page,
      contains(
        'paidCreditPlansEnabled: LaunchContainment.paidCreditPlansEnabled',
      ),
    );
    expect(page, isNot(contains('config.plans.any')));
  });
}
