import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const String migrationPath =
      'supabase/migrations/20260817103615_harden_data_boundaries.sql';

  test('the boundary-hardening migration keeps public tables fail-closed', () {
    final String sql = File(migrationPath).readAsStringSync().toLowerCase();

    expect(sql, contains('drop policy if exists "todos_select_public"'));
    expect(
      sql,
      contains('revoke all on table public.todos from anon, authenticated'),
    );
    expect(
      sql,
      contains(
        'revoke all on table public.purchase_bindings from anon, authenticated',
      ),
    );
  });

  test(
    'quickstart todos migration is classified as non-production demo data',
    () {
      final String sql = File(
        'supabase/migrations/20260714000001_quickstart_todos.sql',
      ).readAsStringSync().toLowerCase();

      expect(sql, contains('internal quickstart compatibility table'));
      expect(sql, contains('not a chronospark product'));
      expect(sql, contains('feature, not account-owned production data'));
      expect(sql, contains('not part of the canonical app'));
      expect(sql, contains('backup/sync contract'));
    },
  );

  test('tenant policies use scalar auth checks and supporting indexes', () {
    final String sql = File(migrationPath).readAsStringSync().toLowerCase();

    expect(sql, contains('(select auth.uid())'));
    expect(sql, contains('purchase_bindings_user_id_idx'));
    expect(sql, contains('user_daily_metrics_user_id_idx'));
    expect(sql, contains('storage.objects'));
    expect(sql, contains("split_part(name, '/', 1)"));
  });

  test('security-definer functions pin search_path and restrict execution', () {
    final String sql = File(migrationPath).readAsStringSync().toLowerCase();

    expect(sql, contains("set search_path = ''"));
    expect(
      sql,
      contains('revoke execute on function public.handle_new_user()'),
    );
    expect(
      sql,
      contains('revoke execute on function public.set_profiles_updated_at()'),
    );
    expect(
      sql,
      contains(
        'revoke execute on function public.set_user_daily_metrics_updated_at()',
      ),
    );
  });
}
