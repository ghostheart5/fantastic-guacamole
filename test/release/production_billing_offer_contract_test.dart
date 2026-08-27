import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('server credit allowances match the published paywall offer', () {
    final String paywall = File(
      'lib/data/repositories/paywall_repository.dart',
    ).readAsStringSync();
    final String migration = File(
      'supabase/migrations/20260827093746_production_billing_authority.sql',
    ).readAsStringSync();

    expect(paywall, contains('aiCreditsIncluded: 300'));
    expect(paywall, contains('aiCreditsIncluded: 360'));
    expect(migration, contains('v_allowance := 300;'));
    expect(migration, contains('v_allowance := 360;'));
    expect(
      migration,
      contains("least(v_status.expires_at, now() + interval '1 month')"),
      reason: 'Annual subscribers receive the advertised monthly allowance.',
    );
    expect(
      migration,
      contains(
        "when 'premium_monthly' then 300 when 'premium_yearly' then 360",
      ),
    );
  });
}
