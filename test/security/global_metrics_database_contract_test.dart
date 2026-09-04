import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('daily metrics upsert targets the live account-scoped primary key', () {
    final String service = File(
      'lib/system/analytics/global_aggregation_service.dart',
    ).readAsStringSync();
    final String migration = File(
      'supabase/migrations/20260717170000_secure_user_daily_metrics.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains(
        'add constraint user_daily_metrics_pkey primary key (user_id, date)',
      ),
    );
    expect(service, contains("onConflict: 'user_id,date'"));
    expect(service, isNot(contains("onConflict: 'device_id,date'")));
  });

  test('Firebase registration is RPC-owned and the legacy table is retired', () {
    final String bridge = File(
      'lib/data/repositories/firebase_supabase_bridge_repository.dart',
    ).readAsStringSync();
    final String auth = File(
      'lib/data/services/auth_service.dart',
    ).readAsStringSync();
    final String migration = File(
      'supabase/migrations/'
      '20260904015011_consolidate_firebase_registration_and_metric_ownership.sql',
    ).readAsStringSync();

    expect(bridge, contains("'register_firebase_device'"));
    expect(bridge, isNot(contains("from('user_push_tokens')")));
    expect(auth, contains("'unregister_firebase_device'"));
    expect(auth, isNot(contains("from('user_push_tokens')")));
    expect(migration, contains('drop table if exists public.user_push_tokens'));
    expect(migration, contains('security definer'));
    expect(migration, contains("set search_path = ''"));
    expect(migration, contains('auth.uid()'));
  });
}
