import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The discard action relies on a migration the owner deploys separately.
/// These checks keep that migration narrow: delete of one's own row only,
/// refused during account deletion, and no other policy touched.
void main() {
  const String migrationPath =
      'supabase/migrations/20261123090000_cloud_backup_discard_own.sql';
  const String pgTapPath =
      'supabase/tests/cloud_backup_snapshots_discard.test.sql';

  String read(String path) => File(path).readAsStringSync();

  String sqlWithoutComments(String sql) => sql
      .split('\n')
      .map((String line) => line.replaceFirst(RegExp(r'--.*$'), ''))
      .join('\n')
      .toLowerCase();

  test('the discard migration only adds delete of the caller\'s own row', () {
    final String sql = sqlWithoutComments(read(migrationPath));

    expect(
      RegExp(
        r'grant\s+(\w[\w\s,]*?)\s+on\s+table',
      ).allMatches(sql).map((Match m) => m.group(1)!.trim()),
      <String>['delete'],
    );
    expect(
      sql,
      contains('grant delete on table public.cloud_backup_snapshots'),
    );
    expect(sql, contains('to authenticated'));
    expect(sql, isNot(contains('revoke')));
    expect(sql, isNot(contains('alter table')));
    expect(sql, isNot(contains('anon')));
    expect(sql, isNot(contains('service_role')));

    final List<String> policies = RegExp(
      r'create\s+policy\s+(\w+)',
    ).allMatches(sql).map((Match m) => m.group(1)!).toList();
    expect(policies, <String>['cloud_backup_snapshots_delete_own']);
    final List<String> dropped = RegExp(
      r'drop\s+policy\s+if\s+exists\s+(\w+)',
    ).allMatches(sql).map((Match m) => m.group(1)!).toList();
    expect(dropped, <String>['cloud_backup_snapshots_delete_own']);

    final String policy = sql.substring(
      sql.indexOf('create policy cloud_backup_snapshots_delete_own'),
    );
    expect(policy, contains('for delete'));
    expect(policy, contains('to authenticated'));
    expect(policy, contains('(select auth.uid()) is not null'));
    expect(policy, contains('(select auth.uid()) = user_id'));
    expect(policy, contains('not public.account_deletion_in_progress()'));
    expect(policy, isNot(contains('with check')));
  });

  test('pgTAP covers owner, other account, deletion and grants', () {
    final String tests = read(pgTapPath);
    for (final String name in <String>[
      'the owner can discard their own snapshot',
      'another account cannot delete the owner snapshot',
      'a deletion tombstone blocks discarding',
      'anonymous clients cannot delete snapshots',
      'select, insert and update policies are unchanged',
    ]) {
      expect(tests, contains(name));
    }
    expect(tests, contains('rollback;'));
  });
}
