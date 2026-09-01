import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const String migrationPath =
      'supabase/migrations/20260830141458_planner_explanation_replay_ttl.sql';
  final String sql = File(migrationPath).readAsStringSync().toLowerCase();

  test('Planner explanation database objects remain service-role only', () {
    expect(
      sql,
      contains(
        'alter table public.planner_explanation_quotes enable row level security',
      ),
    );
    expect(
      sql,
      contains(
        'alter table public.planner_explanation_replays enable row level security',
      ),
    );
    expect(
      sql,
      contains('revoke all on table public.planner_explanation_quotes'),
    );
    expect(
      sql,
      contains('revoke all on table public.planner_explanation_replays'),
    );
    expect(
      sql,
      contains(
        'grant select, insert, update, delete on table public.planner_explanation_quotes',
      ),
    );
    expect(
      sql,
      contains(
        'grant select, insert, update, delete on table public.planner_explanation_replays',
      ),
    );
    expect(sql, isNot(contains('security definer')));
    expect(
      RegExp(r'language plpgsql\s+security invoker').allMatches(sql),
      hasLength(6),
    );
    expect(
      RegExp(r'grant\s+[^;]+\s+to\s+(?:anon|authenticated)\s*;').hasMatch(sql),
      isFalse,
    );
  });

  test('raw response content has a bounded expiry and metadata scrub', () {
    expect(
      sql,
      contains("content_expires_at <= created_at + interval '4 minutes'"),
    );
    expect(
      sql,
      contains("p_content_expires_at > v_now + interval '4 minutes'"),
    );
    expect(
      sql,
      contains("array['explanation', 'sourceclauseids', 'contentexpiresat']"),
    );
    expect(sql, contains("'replaystate', 'content_scrubbed'"));
    expect(sql, contains("'* * * * *'"));
    expect(
      sql,
      contains("'select public.scrub_expired_ai_response_content();'"),
    );
  });

  test('settlement binds the wallet and delegates refunds atomically', () {
    expect(
      sql,
      contains("raise exception 'planner explanation wallet not found'"),
    );
    expect(sql, contains("p_response_payload ->> 'remainingcredits'"));
    expect(sql, contains('v_wallet.balance'));
    expect(sql, contains('return public.settle_ai_usage('));
    expect(sql, contains("v_result ->> 'state' = 'completed'"));
  });
}
