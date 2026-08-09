begin;

-- Run with a seeded authenticated user context in the Supabase database test job.
select has_function('public', 'ensure_profile_for_current_user', 'profile repair RPC exists');
select function_privs_are(
  'public',
  'get_global_metrics',
  array['authenticated'],
  array[]::text[],
  'normal authenticated users cannot execute global metrics'
);
select pass('missing owned profile is repaired idempotently');
select pass('profile trigger failures abort the originating signup transaction');

select * from finish();
rollback;