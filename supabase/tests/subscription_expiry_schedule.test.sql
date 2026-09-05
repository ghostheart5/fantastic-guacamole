begin;

create extension if not exists pgtap with schema extensions;
select plan(9);

select is(
  (select count(*) from cron.job
   where jobname = 'chronospark-expire-subscriptions'),
  1::bigint, 'historical subscription expiry job is preserved'
);
select is(
  (select active from cron.job
   where jobname = 'chronospark-expire-subscriptions'),
  false, 'historical duplicate is inactive after migration replay'
);
select is(
  (select count(*) from cron.job
   where jobname = 'chronospark-expire-stale-subscriptions'),
  1::bigint, 'canonical subscription expiry job exists exactly once'
);
select is(
  (select active from cron.job
   where jobname = 'chronospark-expire-stale-subscriptions'),
  true, 'canonical subscription expiry job remains active'
);
select is(
  (select count(*) from cron.job
   where jobname in ('chronospark-expire-subscriptions',
                    'chronospark-expire-stale-subscriptions')
     and command = 'select public.expire_stale_monetization_subscriptions();'
     and schedule = '*/15 * * * *'
     and database = current_database() and username = 'postgres'),
  2::bigint, 'both job definitions retain the original command and execution identity'
);
select is(
  (select count(*) from cron.job
   where command = 'select public.expire_stale_monetization_subscriptions();'
     and database = current_database() and active),
  1::bigint, 'only one expiration schedule can run in this database'
);
select ok(
  (select old_job.nodename is not distinct from keeper.nodename
          and old_job.nodeport is not distinct from keeper.nodeport
   from cron.job old_job cross join cron.job keeper
   where old_job.jobname = 'chronospark-expire-subscriptions'
     and keeper.jobname = 'chronospark-expire-stale-subscriptions'),
  'historical and canonical schedules retain the same server connection target'
);
select is(
  (select count(*) from cron.job
   where jobname = 'chronospark-refund-stale-ai-reservations' and active),
  1::bigint, 'unrelated stale AI refund schedule remains active'
);
select is(
  (select schedule from cron.job
   where jobname = 'chronospark-refund-stale-ai-reservations'),
  '*/5 * * * *', 'unrelated refund cadence is unchanged'
);

select * from finish();
rollback;
