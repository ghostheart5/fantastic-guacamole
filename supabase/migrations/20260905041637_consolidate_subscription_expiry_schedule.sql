-- Preserve cron history while making the already-approved operational repair
-- durable on fresh migration replay. Never execute the expiration function here.
-- Both predecessors must still match the known contract; drift needs review.
do $$
declare
  v_old cron.job%rowtype;
  v_keeper cron.job%rowtype;
  v_command constant text := 'select public.expire_stale_monetization_subscriptions();';
begin
  if (select count(*) from cron.job
      where jobname = 'chronospark-expire-subscriptions') <> 1
     or (select count(*) from cron.job
         where jobname = 'chronospark-expire-stale-subscriptions') <> 1 then
    raise exception 'subscription expiry job identities changed; review before migration';
  end if;

  select * into strict v_old from cron.job
    where jobname = 'chronospark-expire-subscriptions';
  select * into strict v_keeper from cron.job
    where jobname = 'chronospark-expire-stale-subscriptions';

  if v_old.command is distinct from v_command
     or v_keeper.command is distinct from v_command
     or v_old.schedule is distinct from '*/15 * * * *'
     or v_keeper.schedule is distinct from v_old.schedule
     or v_old.database is distinct from current_database()
     or v_keeper.database is distinct from v_old.database
     or v_old.username is distinct from 'postgres'
     or v_keeper.username is distinct from v_old.username
     or v_keeper.nodename is distinct from v_old.nodename
     or v_keeper.nodeport is distinct from v_old.nodeport
     or v_keeper.active is distinct from true then
    raise exception 'subscription expiry job configuration changed; review before migration';
  end if;

  if exists (select 1 from cron.job
      where command = v_command and database = v_keeper.database and active
        and jobid not in (v_old.jobid, v_keeper.jobid)) then
    raise exception 'unexpected active subscription expiry job; review before migration';
  end if;

  -- Idempotent when the production operational repair has already paused it.
  if v_old.active then
    perform cron.alter_job(job_id := v_old.jobid, active := false);
  end if;

  if (select count(*) from cron.job
      where command = v_command and database = v_keeper.database and active) <> 1
     or not exists (select 1 from cron.job
         where jobid = v_keeper.jobid and active) then
    raise exception 'subscription expiry consolidation postcondition failed';
  end if;
end;
$$;
