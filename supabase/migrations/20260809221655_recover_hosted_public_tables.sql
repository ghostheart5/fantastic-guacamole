-- Recover the 24 public tables that existed only in the hosted project.
--
-- The source catalog was captured read-only on 2026-08-09. This migration
-- contains schema metadata only: no production rows or user data.
-- It is idempotent against the existing hosted schema and creates the full
-- table set during a clean local/staging reset.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.sync_app_events_legacy_fields()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if (new.event_name is null or new.event_name = '') and new.event_type is not null then
    new.event_name := new.event_type;
  end if;

  if (new.metadata is null or new.metadata = '{}'::jsonb) and new.event_payload is not null then
    new.metadata := new.event_payload;
  end if;

  if new.metadata is null then
    new.metadata := '{}'::jsonb;
  end if;

  return new;
end;
$$;

revoke all on function public.set_updated_at() from public, anon, authenticated, service_role;
revoke all on function public.sync_app_events_legacy_fields() from public, anon, authenticated, service_role;

create table if not exists public."achievements" (
  "id" uuid default gen_random_uuid() not null,
  "key" text not null,
  "title" text not null,
  "description" text,
  "icon_url" text,
  "target_value" integer,
  "reward" jsonb default '{}'::jsonb not null,
  "is_active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "achievement_key" text not null,
  "icon_name" text,
  "category" text,
  "points" integer default 0 not null
);
alter table public."achievements" enable row level security;

create table if not exists public."admin_users" (
  "user_id" uuid not null,
  "created_at" timestamp with time zone default now() not null
);
alter table public."admin_users" enable row level security;

create table if not exists public."app_announcements" (
  "id" uuid default gen_random_uuid() not null,
  "title" text not null,
  "body" text not null,
  "level" text default 'info'::text not null,
  "is_active" boolean default true not null,
  "published_at" timestamp with time zone default now() not null,
  "metadata" jsonb default '{}'::jsonb not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null
);
alter table public."app_announcements" enable row level security;

create table if not exists public."app_events" (
  "id" uuid default gen_random_uuid() not null,
  "event_type" text not null,
  "event_payload" jsonb default '{}'::jsonb not null,
  "occurred_at" timestamp with time zone default now() not null,
  "created_at" timestamp with time zone default now() not null,
  "user_id" uuid,
  "event_name" text not null,
  "event_category" text,
  "screen_name" text,
  "metadata" jsonb default '{}'::jsonb not null
);
alter table public."app_events" enable row level security;

create table if not exists public."core_values" (
  "id" uuid default gen_random_uuid() not null,
  "created_at" timestamp with time zone default now() not null,
  "user_id" uuid default gen_random_uuid() not null,
  "name" text default 'text'::text not null,
  "description" text default 'text'::text not null,
  "score" smallint default '0'::smallint not null,
  "updated_at" timestamp with time zone default now() not null,
  "deleted_at" timestamp with time zone
);
alter table public."core_values" enable row level security;

create table if not exists public."entitlement_events" (
  "id" uuid default gen_random_uuid() not null,
  "user_id" uuid not null,
  "event_type" text not null,
  "source" text,
  "external_id" text,
  "status" text default 'processed'::text not null,
  "occurred_at" timestamp with time zone default now() not null,
  "metadata" jsonb default '{}'::jsonb not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null
);
alter table public."entitlement_events" enable row level security;

create table if not exists public."feedback_reports" (
  "id" uuid default gen_random_uuid() not null,
  "user_id" uuid not null,
  "subject" text,
  "message" text not null,
  "rating" integer,
  "metadata" jsonb default '{}'::jsonb not null,
  "status" text default 'submitted'::text not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null
);
alter table public."feedback_reports" enable row level security;

create table if not exists public."focus_sessions" (
  "id" uuid default gen_random_uuid() not null,
  "user_id" uuid not null,
  "started_at" timestamp with time zone not null,
  "ended_at" timestamp with time zone,
  "duration_minutes" integer default 0 not null,
  "session_type" text default 'focus'::text,
  "metadata" jsonb default '{}'::jsonb not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "title" text,
  "linked_task_id" text,
  "linked_goal_id" text,
  "notes" text,
  "completed" boolean default false not null
);
alter table public."focus_sessions" enable row level security;

create table if not exists public."goal_checkins" (
  "id" uuid default gen_random_uuid() not null,
  "user_id" uuid not null,
  "goal_id" text not null,
  "checkin_date" date not null,
  "progress_value" integer,
  "note" text,
  "mood" text,
  "metadata" jsonb default '{}'::jsonb not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null
);
alter table public."goal_checkins" enable row level security;

create table if not exists public."habit entries" (
  "id" uuid default gen_random_uuid() not null,
  "created_at" timestamp with time zone default now() not null,
  "completed_date" date not null,
  "habit_id" uuid default gen_random_uuid() not null,
  "user_id" uuid not null
);
alter table public."habit entries" enable row level security;

create table if not exists public."memoryEngine" (
  "id" bigint generated by default as identity not null,
  "created_at" timestamp with time zone default now() not null,
  "title" text not null,
  "memory_text" text not null,
  "memory_type" text not null,
  "updated_at" timestamp with time zone default now() not null,
  "deleted_at" timestamp with time zone,
  "user_id" uuid not null
);
alter table public."memoryEngine" enable row level security;

create table if not exists public."milestones" (
  "id" uuid default gen_random_uuid() not null,
  "created_at" timestamp with time zone default now() not null,
  "user_id" uuid default gen_random_uuid() not null,
  "title" text not null,
  "description" text not null,
  "updated_at" timestamp with time zone default now() not null,
  "deleted_at" timestamp with time zone
);
alter table public."milestones" enable row level security;

create table if not exists public."notifications" (
  "id" uuid default gen_random_uuid() not null,
  "created_at" timestamp with time zone default now() not null,
  "user_id" uuid default gen_random_uuid() not null,
  "title" text not null,
  "body" text not null,
  "is_read" boolean not null,
  "updated_at" timestamp with time zone default now() not null,
  "deleted_at" timestamp with time zone
);
alter table public."notifications" enable row level security;

create table if not exists public."recurring_rules" (
  "id" uuid default gen_random_uuid() not null,
  "user_id" uuid not null,
  "rule_type" text not null,
  "entity_type" text not null,
  "entity_id" uuid not null,
  "schedule" jsonb default '{}'::jsonb not null,
  "is_active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "source_table" text,
  "source_id" uuid,
  "frequency" text,
  "interval_count" integer default 1 not null,
  "days_of_week" integer[] default '{}'::integer[],
  "day_of_month" integer,
  "start_date" date default CURRENT_DATE not null,
  "end_date" date,
  "next_run_date" date,
  "timezone" text default 'America/Chicago'::text
);
alter table public."recurring_rules" enable row level security;

create table if not exists public."smart coach notes" (
  "id" uuid default gen_random_uuid() not null,
  "created_at" timestamp with time zone default now() not null,
  "user_id" uuid default gen_random_uuid() not null,
  "note" text not null,
  "coach_response" text not null,
  "title" text default ''::text not null
);
alter table public."smart coach notes" enable row level security;

create table if not exists public."soul_maps" (
  "id" uuid default gen_random_uuid() not null,
  "user_id" uuid not null,
  "title" text,
  "vision" text,
  "identity_statement" text,
  "life_theme" text,
  "core_values" jsonb,
  "milestones" jsonb,
  "future_goals" jsonb,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "deleted_at" timestamp with time zone
);
alter table public."soul_maps" enable row level security;

create table if not exists public."streaks" (
  "id" uuid default gen_random_uuid() not null,
  "user_id" uuid not null,
  "entity_type" text not null,
  "entity_id" uuid not null,
  "current_streak" integer default 0 not null,
  "best_streak" integer default 0 not null,
  "last_completed_at" timestamp with time zone,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "streak_type" text default ''::text not null,
  "source_table" text,
  "source_id" uuid,
  "current_count" integer default 0 not null,
  "longest_count" integer default 0 not null,
  "last_completed_date" date,
  "is_active" boolean default true not null
);
alter table public."streaks" enable row level security;

create table if not exists public."subscriptions" (
  "id" uuid default gen_random_uuid() not null,
  "user_id" uuid not null,
  "provider" text default 'stripe'::text not null,
  "provider_subscription_id" text,
  "plan_id" text,
  "status" text default 'active'::text not null,
  "started_at" timestamp with time zone,
  "current_period_start" timestamp with time zone,
  "current_period_end" timestamp with time zone,
  "canceled_at" timestamp with time zone,
  "metadata" jsonb default '{}'::jsonb not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null
);
alter table public."subscriptions" enable row level security;

create table if not exists public."sync_queue" (
  "id" uuid default gen_random_uuid() not null,
  "user_id" uuid,
  "job_type" text not null,
  "payload" jsonb default '{}'::jsonb not null,
  "status" text default 'pending'::text not null,
  "attempts" integer default 0 not null,
  "available_at" timestamp with time zone default now() not null,
  "locked_at" timestamp with time zone,
  "locked_by" text,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null
);
alter table public."sync_queue" enable row level security;

create table if not exists public."task_steps" (
  "id" uuid default gen_random_uuid() not null,
  "user_id" uuid not null,
  "task_id" text not null,
  "step_index" integer not null,
  "title" text not null,
  "notes" text,
  "status" text default 'todo'::text not null,
  "due_at" timestamp with time zone,
  "completed_at" timestamp with time zone,
  "metadata" jsonb default '{}'::jsonb not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "is_completed" boolean default false not null,
  "sort_order" integer default 0 not null
);
alter table public."task_steps" enable row level security;

create table if not exists public."timeline_events" (
  "id" uuid default gen_random_uuid() not null,
  "created_at" timestamp with time zone default now() not null,
  "user_id" uuid default gen_random_uuid() not null,
  "title" text not null,
  "description" text not null,
  "start_date" timestamp with time zone not null,
  "end_date" timestamp with time zone not null,
  "updated_at" timestamp with time zone default now() not null,
  "deleted_at" timestamp with time zone
);
alter table public."timeline_events" enable row level security;

create table if not exists public."user_achievements" (
  "id" uuid default gen_random_uuid() not null,
  "user_id" uuid not null,
  "achievement_id" uuid not null,
  "unlocked_at" timestamp with time zone default now() not null,
  "progress_value" integer default 0 not null,
  "metadata" jsonb default '{}'::jsonb not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null
);
alter table public."user_achievements" enable row level security;

create table if not exists public."user_devices" (
  "id" uuid default gen_random_uuid() not null,
  "user_id" uuid not null,
  "device_token" text not null,
  "device_type" text,
  "platform" text,
  "last_seen_at" timestamp with time zone,
  "metadata" jsonb default '{}'::jsonb not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "fcm_token" text,
  "app_version" text,
  "notifications_enabled" boolean default true not null
);
alter table public."user_devices" enable row level security;

create table if not exists public."webhook_events" (
  "id" uuid default gen_random_uuid() not null,
  "event_type" text not null,
  "user_id" uuid,
  "payload" jsonb default '{}'::jsonb not null,
  "created_at" timestamp with time zone default now() not null
);
alter table public."webhook_events" enable row level security;

-- Add constraints only when the hosted constraint name is absent.
do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."achievements"'::regclass
      and conname = 'achievements_pkey'
  ) then
    execute $constraint_sql$alter table public."achievements" add constraint "achievements_pkey" PRIMARY KEY (id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."admin_users"'::regclass
      and conname = 'admin_users_pkey'
  ) then
    execute $constraint_sql$alter table public."admin_users" add constraint "admin_users_pkey" PRIMARY KEY (user_id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."app_announcements"'::regclass
      and conname = 'app_announcements_pkey'
  ) then
    execute $constraint_sql$alter table public."app_announcements" add constraint "app_announcements_pkey" PRIMARY KEY (id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."app_events"'::regclass
      and conname = 'app_events_pkey'
  ) then
    execute $constraint_sql$alter table public."app_events" add constraint "app_events_pkey" PRIMARY KEY (id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."core_values"'::regclass
      and conname = 'core_values_pkey'
  ) then
    execute $constraint_sql$alter table public."core_values" add constraint "core_values_pkey" PRIMARY KEY (id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."entitlement_events"'::regclass
      and conname = 'entitlement_events_pkey'
  ) then
    execute $constraint_sql$alter table public."entitlement_events" add constraint "entitlement_events_pkey" PRIMARY KEY (id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."feedback_reports"'::regclass
      and conname = 'feedback_reports_pkey'
  ) then
    execute $constraint_sql$alter table public."feedback_reports" add constraint "feedback_reports_pkey" PRIMARY KEY (id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."focus_sessions"'::regclass
      and conname = 'focus_sessions_pkey'
  ) then
    execute $constraint_sql$alter table public."focus_sessions" add constraint "focus_sessions_pkey" PRIMARY KEY (id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."goal_checkins"'::regclass
      and conname = 'goal_checkins_pkey'
  ) then
    execute $constraint_sql$alter table public."goal_checkins" add constraint "goal_checkins_pkey" PRIMARY KEY (id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."habit entries"'::regclass
      and conname = 'habit entries_pkey'
  ) then
    execute $constraint_sql$alter table public."habit entries" add constraint "habit entries_pkey" PRIMARY KEY (id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."memoryEngine"'::regclass
      and conname = 'memoryEngine_pkey'
  ) then
    execute $constraint_sql$alter table public."memoryEngine" add constraint "memoryEngine_pkey" PRIMARY KEY (id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."milestones"'::regclass
      and conname = 'milestones_pkey'
  ) then
    execute $constraint_sql$alter table public."milestones" add constraint "milestones_pkey" PRIMARY KEY (id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."notifications"'::regclass
      and conname = 'notifications_pkey'
  ) then
    execute $constraint_sql$alter table public."notifications" add constraint "notifications_pkey" PRIMARY KEY (id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."recurring_rules"'::regclass
      and conname = 'recurring_rules_pkey'
  ) then
    execute $constraint_sql$alter table public."recurring_rules" add constraint "recurring_rules_pkey" PRIMARY KEY (id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."smart coach notes"'::regclass
      and conname = 'smart coach notes_pkey'
  ) then
    execute $constraint_sql$alter table public."smart coach notes" add constraint "smart coach notes_pkey" PRIMARY KEY (id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."soul_maps"'::regclass
      and conname = 'soul_maps_pkey'
  ) then
    execute $constraint_sql$alter table public."soul_maps" add constraint "soul_maps_pkey" PRIMARY KEY (id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."streaks"'::regclass
      and conname = 'streaks_pkey'
  ) then
    execute $constraint_sql$alter table public."streaks" add constraint "streaks_pkey" PRIMARY KEY (id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."subscriptions"'::regclass
      and conname = 'subscriptions_pkey'
  ) then
    execute $constraint_sql$alter table public."subscriptions" add constraint "subscriptions_pkey" PRIMARY KEY (id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."sync_queue"'::regclass
      and conname = 'sync_queue_pkey'
  ) then
    execute $constraint_sql$alter table public."sync_queue" add constraint "sync_queue_pkey" PRIMARY KEY (id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."task_steps"'::regclass
      and conname = 'task_steps_pkey'
  ) then
    execute $constraint_sql$alter table public."task_steps" add constraint "task_steps_pkey" PRIMARY KEY (id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."timeline_events"'::regclass
      and conname = 'timeline_events_pkey'
  ) then
    execute $constraint_sql$alter table public."timeline_events" add constraint "timeline_events_pkey" PRIMARY KEY (id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."user_achievements"'::regclass
      and conname = 'user_achievements_pkey'
  ) then
    execute $constraint_sql$alter table public."user_achievements" add constraint "user_achievements_pkey" PRIMARY KEY (id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."user_devices"'::regclass
      and conname = 'user_devices_pkey'
  ) then
    execute $constraint_sql$alter table public."user_devices" add constraint "user_devices_pkey" PRIMARY KEY (id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."webhook_events"'::regclass
      and conname = 'webhook_events_pkey'
  ) then
    execute $constraint_sql$alter table public."webhook_events" add constraint "webhook_events_pkey" PRIMARY KEY (id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."achievements"'::regclass
      and conname = 'achievements_achievement_key_key'
  ) then
    execute $constraint_sql$alter table public."achievements" add constraint "achievements_achievement_key_key" UNIQUE (achievement_key)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."achievements"'::regclass
      and conname = 'achievements_key_key'
  ) then
    execute $constraint_sql$alter table public."achievements" add constraint "achievements_key_key" UNIQUE (key)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."entitlement_events"'::regclass
      and conname = 'entitlement_events_unique'
  ) then
    execute $constraint_sql$alter table public."entitlement_events" add constraint "entitlement_events_unique" UNIQUE (user_id, event_type, external_id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."goal_checkins"'::regclass
      and conname = 'goal_checkins_unique_per_day'
  ) then
    execute $constraint_sql$alter table public."goal_checkins" add constraint "goal_checkins_unique_per_day" UNIQUE (user_id, goal_id, checkin_date)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."recurring_rules"'::regclass
      and conname = 'recurring_rules_unique'
  ) then
    execute $constraint_sql$alter table public."recurring_rules" add constraint "recurring_rules_unique" UNIQUE (user_id, rule_type, entity_type, entity_id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."streaks"'::regclass
      and conname = 'streaks_unique_entity'
  ) then
    execute $constraint_sql$alter table public."streaks" add constraint "streaks_unique_entity" UNIQUE (user_id, entity_type, entity_id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."subscriptions"'::regclass
      and conname = 'subscriptions_unique_provider_id'
  ) then
    execute $constraint_sql$alter table public."subscriptions" add constraint "subscriptions_unique_provider_id" UNIQUE (provider, provider_subscription_id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."task_steps"'::regclass
      and conname = 'task_steps_unique_order'
  ) then
    execute $constraint_sql$alter table public."task_steps" add constraint "task_steps_unique_order" UNIQUE (user_id, task_id, step_index)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."user_achievements"'::regclass
      and conname = 'user_achievements_unique'
  ) then
    execute $constraint_sql$alter table public."user_achievements" add constraint "user_achievements_unique" UNIQUE (user_id, achievement_id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."user_devices"'::regclass
      and conname = 'user_devices_unique_token'
  ) then
    execute $constraint_sql$alter table public."user_devices" add constraint "user_devices_unique_token" UNIQUE (user_id, device_token)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."user_devices"'::regclass
      and conname = 'user_devices_user_id_fcm_token_uniq'
  ) then
    execute $constraint_sql$alter table public."user_devices" add constraint "user_devices_user_id_fcm_token_uniq" UNIQUE (user_id, fcm_token)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."feedback_reports"'::regclass
      and conname = 'feedback_reports_rating_check'
  ) then
    execute $constraint_sql$alter table public."feedback_reports" add constraint "feedback_reports_rating_check" CHECK (rating IS NULL OR rating >= 1 AND rating <= 5)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."admin_users"'::regclass
      and conname = 'admin_users_user_id_fkey'
  ) then
    execute $constraint_sql$alter table public."admin_users" add constraint "admin_users_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."app_events"'::regclass
      and conname = 'app_events_user_id_fkey'
  ) then
    execute $constraint_sql$alter table public."app_events" add constraint "app_events_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."entitlement_events"'::regclass
      and conname = 'entitlement_events_user_id_fkey'
  ) then
    execute $constraint_sql$alter table public."entitlement_events" add constraint "entitlement_events_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."feedback_reports"'::regclass
      and conname = 'feedback_reports_user_id_fkey'
  ) then
    execute $constraint_sql$alter table public."feedback_reports" add constraint "feedback_reports_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."focus_sessions"'::regclass
      and conname = 'focus_sessions_linked_goal_id_fkey'
  ) then
    execute $constraint_sql$alter table public."focus_sessions" add constraint "focus_sessions_linked_goal_id_fkey" FOREIGN KEY (user_id, linked_goal_id) REFERENCES goals(user_id, id) ON DELETE SET NULL (linked_goal_id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."focus_sessions"'::regclass
      and conname = 'focus_sessions_linked_task_id_fkey'
  ) then
    execute $constraint_sql$alter table public."focus_sessions" add constraint "focus_sessions_linked_task_id_fkey" FOREIGN KEY (user_id, linked_task_id) REFERENCES tasks(user_id, id) ON DELETE SET NULL (linked_task_id)$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."focus_sessions"'::regclass
      and conname = 'focus_sessions_user_id_fkey'
  ) then
    execute $constraint_sql$alter table public."focus_sessions" add constraint "focus_sessions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."goal_checkins"'::regclass
      and conname = 'goal_checkins_goal_id_fkey'
  ) then
    execute $constraint_sql$alter table public."goal_checkins" add constraint "goal_checkins_goal_id_fkey" FOREIGN KEY (user_id, goal_id) REFERENCES goals(user_id, id) ON DELETE CASCADE$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."goal_checkins"'::regclass
      and conname = 'goal_checkins_user_id_fkey'
  ) then
    execute $constraint_sql$alter table public."goal_checkins" add constraint "goal_checkins_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."memoryEngine"'::regclass
      and conname = 'memoryengine_user_id_fkey'
  ) then
    execute $constraint_sql$alter table public."memoryEngine" add constraint "memoryengine_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."recurring_rules"'::regclass
      and conname = 'recurring_rules_user_id_fkey'
  ) then
    execute $constraint_sql$alter table public."recurring_rules" add constraint "recurring_rules_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."streaks"'::regclass
      and conname = 'streaks_user_id_fkey'
  ) then
    execute $constraint_sql$alter table public."streaks" add constraint "streaks_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."subscriptions"'::regclass
      and conname = 'subscriptions_user_id_fkey'
  ) then
    execute $constraint_sql$alter table public."subscriptions" add constraint "subscriptions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."sync_queue"'::regclass
      and conname = 'sync_queue_user_id_fkey'
  ) then
    execute $constraint_sql$alter table public."sync_queue" add constraint "sync_queue_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."task_steps"'::regclass
      and conname = 'task_steps_task_id_fkey'
  ) then
    execute $constraint_sql$alter table public."task_steps" add constraint "task_steps_task_id_fkey" FOREIGN KEY (user_id, task_id) REFERENCES tasks(user_id, id) ON DELETE CASCADE$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."task_steps"'::regclass
      and conname = 'task_steps_user_id_fkey'
  ) then
    execute $constraint_sql$alter table public."task_steps" add constraint "task_steps_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."user_achievements"'::regclass
      and conname = 'user_achievements_achievement_id_fkey'
  ) then
    execute $constraint_sql$alter table public."user_achievements" add constraint "user_achievements_achievement_id_fkey" FOREIGN KEY (achievement_id) REFERENCES achievements(id) ON DELETE CASCADE$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."user_achievements"'::regclass
      and conname = 'user_achievements_user_id_fkey'
  ) then
    execute $constraint_sql$alter table public."user_achievements" add constraint "user_achievements_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE$constraint_sql$;
  end if;
end;
$constraint$;

do $constraint$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public."user_devices"'::regclass
      and conname = 'user_devices_user_id_fkey'
  ) then
    execute $constraint_sql$alter table public."user_devices" add constraint "user_devices_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE$constraint_sql$;
  end if;
end;
$constraint$;

-- Recreate non-constraint indexes.
create index if not exists achievements_category_idx ON public.achievements USING btree (category);
create index if not exists achievements_key_idx ON public.achievements USING btree (achievement_key);
create index if not exists admin_users_user_id_idx ON public.admin_users USING btree (user_id);
create index if not exists app_events_created_at_idx ON public.app_events USING btree (created_at);
create index if not exists app_events_event_name_idx ON public.app_events USING btree (event_name);
create index if not exists app_events_user_id_idx ON public.app_events USING btree (user_id);
create index if not exists entitlement_events_user_created_at_idx ON public.entitlement_events USING btree (user_id, created_at DESC);
create index if not exists idx_entitlement_events_user ON public.entitlement_events USING btree (user_id, occurred_at);
create index if not exists feedback_reports_status_idx ON public.feedback_reports USING btree (status);
create index if not exists feedback_reports_user_id_idx ON public.feedback_reports USING btree (user_id);
create index if not exists idx_feedback_reports_user_created ON public.feedback_reports USING btree (user_id, created_at);
create index if not exists focus_sessions_completed_idx ON public.focus_sessions USING btree (completed);
create index if not exists focus_sessions_linked_goal_id_idx ON public.focus_sessions USING btree (linked_goal_id);
create index if not exists focus_sessions_linked_task_id_idx ON public.focus_sessions USING btree (linked_task_id);
create index if not exists focus_sessions_started_at_idx ON public.focus_sessions USING btree (started_at);
create index if not exists focus_sessions_user_id_idx ON public.focus_sessions USING btree (user_id);
create index if not exists idx_focus_sessions_user_start ON public.focus_sessions USING btree (user_id, started_at);
create index if not exists goal_checkins_date_idx ON public.goal_checkins USING btree (checkin_date);
create index if not exists goal_checkins_goal_id_idx ON public.goal_checkins USING btree (goal_id);
create index if not exists goal_checkins_user_id_idx ON public.goal_checkins USING btree (user_id);
create index if not exists idx_goal_checkins_user_goal_date ON public.goal_checkins USING btree (user_id, goal_id, checkin_date);
create index if not exists memoryengine_user_id_idx ON public."memoryEngine" USING btree (user_id);
create index if not exists milestones_user_id_idx ON public.milestones USING btree (user_id);
create index if not exists idx_recurring_rules_user_entity ON public.recurring_rules USING btree (user_id, entity_type, entity_id);
create index if not exists recurring_rules_next_run_idx ON public.recurring_rules USING btree (next_run_date);
create index if not exists recurring_rules_user_id_idx ON public.recurring_rules USING btree (user_id);
create index if not exists idx_streaks_user_entity ON public.streaks USING btree (user_id, entity_type, entity_id);
create index if not exists streaks_type_idx ON public.streaks USING btree (streak_type);
create index if not exists streaks_user_id_idx ON public.streaks USING btree (user_id);
create index if not exists idx_subscriptions_user ON public.subscriptions USING btree (user_id);
create index if not exists idx_sync_queue_status_available ON public.sync_queue USING btree (status, available_at);
create index if not exists idx_sync_queue_user ON public.sync_queue USING btree (user_id);
create index if not exists idx_task_steps_user_task ON public.task_steps USING btree (user_id, task_id);
create index if not exists task_steps_task_id_idx ON public.task_steps USING btree (task_id);
create index if not exists task_steps_user_id_idx ON public.task_steps USING btree (user_id);
create index if not exists idx_user_achievements_user ON public.user_achievements USING btree (user_id);
create index if not exists user_achievements_achievement_id_idx ON public.user_achievements USING btree (achievement_id);
create index if not exists idx_user_devices_user_token ON public.user_devices USING btree (user_id, device_token);
create index if not exists user_devices_fcm_token_idx ON public.user_devices USING btree (fcm_token);
create index if not exists user_devices_user_id_idx ON public.user_devices USING btree (user_id);

-- Recreate RLS policies. PUBLIC ownership policies are intentionally
-- narrowed to authenticated; anon receives no table privileges below.
do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."achievements"'::regclass
      and polname = 'Achievements read (authenticated)'
  ) then
    execute $policy_sql$
  create policy "Achievements read (authenticated)"
  on public."achievements"
  as permissive
  for select
  to "authenticated"
  using ((is_active = true))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."admin_users"'::regclass
      and polname = 'admin_users_select_own'
  ) then
    execute $policy_sql$
  create policy "admin_users_select_own"
  on public."admin_users"
  as permissive
  for select
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."app_announcements"'::regclass
      and polname = 'app_announcements_select'
  ) then
    execute $policy_sql$
  create policy "app_announcements_select"
  on public."app_announcements"
  as permissive
  for select
  to "authenticated"
  using ((is_active = true))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."app_events"'::regclass
      and polname = 'App events delete own'
  ) then
    execute $policy_sql$
  create policy "App events delete own"
  on public."app_events"
  as permissive
  for delete
  to "authenticated"
  using (((( SELECT auth.uid() AS uid) IS NOT NULL) AND (user_id = ( SELECT auth.uid() AS uid))))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."app_events"'::regclass
      and polname = 'App events insert own'
  ) then
    execute $policy_sql$
  create policy "App events insert own"
  on public."app_events"
  as permissive
  for insert
  to "authenticated"
  with check ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."app_events"'::regclass
      and polname = 'App events select own'
  ) then
    execute $policy_sql$
  create policy "App events select own"
  on public."app_events"
  as permissive
  for select
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."app_events"'::regclass
      and polname = 'App events update own'
  ) then
    execute $policy_sql$
  create policy "App events update own"
  on public."app_events"
  as permissive
  for update
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
  with check ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."core_values"'::regclass
      and polname = 'core_values_delete_own'
  ) then
    execute $policy_sql$
  create policy "core_values_delete_own"
  on public."core_values"
  as permissive
  for delete
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."core_values"'::regclass
      and polname = 'core_values_insert_own'
  ) then
    execute $policy_sql$
  create policy "core_values_insert_own"
  on public."core_values"
  as permissive
  for insert
  to "authenticated"
  with check ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."core_values"'::regclass
      and polname = 'core_values_select_own'
  ) then
    execute $policy_sql$
  create policy "core_values_select_own"
  on public."core_values"
  as permissive
  for select
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."core_values"'::regclass
      and polname = 'core_values_update_own'
  ) then
    execute $policy_sql$
  create policy "core_values_update_own"
  on public."core_values"
  as permissive
  for update
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
  with check ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."entitlement_events"'::regclass
      and polname = 'entitlement_events_delete_own'
  ) then
    execute $policy_sql$
  create policy "entitlement_events_delete_own"
  on public."entitlement_events"
  as permissive
  for delete
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."entitlement_events"'::regclass
      and polname = 'entitlement_events_insert_own'
  ) then
    execute $policy_sql$
  create policy "entitlement_events_insert_own"
  on public."entitlement_events"
  as permissive
  for insert
  to "authenticated"
  with check ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."entitlement_events"'::regclass
      and polname = 'entitlement_events_insert_service_role'
  ) then
    execute $policy_sql$
  create policy "entitlement_events_insert_service_role"
  on public."entitlement_events"
  as permissive
  for insert
  to "service_role"
  with check (true)
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."entitlement_events"'::regclass
      and polname = 'entitlement_events_select_own'
  ) then
    execute $policy_sql$
  create policy "entitlement_events_select_own"
  on public."entitlement_events"
  as permissive
  for select
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."entitlement_events"'::regclass
      and polname = 'entitlement_events_update_own'
  ) then
    execute $policy_sql$
  create policy "entitlement_events_update_own"
  on public."entitlement_events"
  as permissive
  for update
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
  with check ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."feedback_reports"'::regclass
      and polname = 'feedback_reports_delete_own'
  ) then
    execute $policy_sql$
  create policy "feedback_reports_delete_own"
  on public."feedback_reports"
  as permissive
  for delete
  to "authenticated"
  using (((user_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM admin_users au
  WHERE (au.user_id = ( SELECT auth.uid() AS uid))))))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."feedback_reports"'::regclass
      and polname = 'feedback_reports_insert_own'
  ) then
    execute $policy_sql$
  create policy "feedback_reports_insert_own"
  on public."feedback_reports"
  as permissive
  for insert
  to "authenticated"
  with check ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."feedback_reports"'::regclass
      and polname = 'feedback_reports_select_own'
  ) then
    execute $policy_sql$
  create policy "feedback_reports_select_own"
  on public."feedback_reports"
  as permissive
  for select
  to "authenticated"
  using (((user_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM admin_users au
  WHERE (au.user_id = ( SELECT auth.uid() AS uid))))))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."feedback_reports"'::regclass
      and polname = 'feedback_reports_update_own'
  ) then
    execute $policy_sql$
  create policy "feedback_reports_update_own"
  on public."feedback_reports"
  as permissive
  for update
  to "authenticated"
  using (((user_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM admin_users au
  WHERE (au.user_id = ( SELECT auth.uid() AS uid))))))
  with check (((user_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM admin_users au
  WHERE (au.user_id = ( SELECT auth.uid() AS uid))))))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."focus_sessions"'::regclass
      and polname = 'Focus sessions delete'
  ) then
    execute $policy_sql$
  create policy "Focus sessions delete"
  on public."focus_sessions"
  as permissive
  for delete
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."focus_sessions"'::regclass
      and polname = 'Focus sessions insert'
  ) then
    execute $policy_sql$
  create policy "Focus sessions insert"
  on public."focus_sessions"
  as permissive
  for insert
  to "authenticated"
  with check ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."focus_sessions"'::regclass
      and polname = 'Focus sessions read'
  ) then
    execute $policy_sql$
  create policy "Focus sessions read"
  on public."focus_sessions"
  as permissive
  for select
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."focus_sessions"'::regclass
      and polname = 'Focus sessions update'
  ) then
    execute $policy_sql$
  create policy "Focus sessions update"
  on public."focus_sessions"
  as permissive
  for update
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
  with check ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."goal_checkins"'::regclass
      and polname = 'goal_checkins_delete_own'
  ) then
    execute $policy_sql$
  create policy "goal_checkins_delete_own"
  on public."goal_checkins"
  as permissive
  for delete
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."goal_checkins"'::regclass
      and polname = 'goal_checkins_insert_own'
  ) then
    execute $policy_sql$
  create policy "goal_checkins_insert_own"
  on public."goal_checkins"
  as permissive
  for insert
  to "authenticated"
  with check ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."goal_checkins"'::regclass
      and polname = 'goal_checkins_select_own'
  ) then
    execute $policy_sql$
  create policy "goal_checkins_select_own"
  on public."goal_checkins"
  as permissive
  for select
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."goal_checkins"'::regclass
      and polname = 'goal_checkins_update_own'
  ) then
    execute $policy_sql$
  create policy "goal_checkins_update_own"
  on public."goal_checkins"
  as permissive
  for update
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
  with check ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."habit entries"'::regclass
      and polname = 'habit entries - delete own'
  ) then
    execute $policy_sql$
  create policy "habit entries - delete own"
  on public."habit entries"
  as permissive
  for delete
  to "authenticated"
  using ((( SELECT auth.uid() AS uid) = user_id))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."habit entries"'::regclass
      and polname = 'habit entries - insert habit belongs'
  ) then
    execute $policy_sql$
  create policy "habit entries - insert habit belongs"
  on public."habit entries"
  as restrictive
  for insert
  to "authenticated"
  with check ((EXISTS ( SELECT 1
   FROM habits h
  WHERE ((h.id = "habit entries".habit_id) AND (h.user_id = ( SELECT auth.uid() AS uid))))))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."habit entries"'::regclass
      and polname = 'habit entries - insert own'
  ) then
    execute $policy_sql$
  create policy "habit entries - insert own"
  on public."habit entries"
  as permissive
  for insert
  to "authenticated"
  with check ((( SELECT auth.uid() AS uid) = user_id))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."habit entries"'::regclass
      and polname = 'habit entries - select own'
  ) then
    execute $policy_sql$
  create policy "habit entries - select own"
  on public."habit entries"
  as permissive
  for select
  to "authenticated"
  using ((( SELECT auth.uid() AS uid) = user_id))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."habit entries"'::regclass
      and polname = 'habit entries - update habit belongs'
  ) then
    execute $policy_sql$
  create policy "habit entries - update habit belongs"
  on public."habit entries"
  as restrictive
  for update
  to "authenticated"
  using ((EXISTS ( SELECT 1
   FROM habits h
  WHERE ((h.id = "habit entries".habit_id) AND (h.user_id = ( SELECT auth.uid() AS uid))))))
  with check ((EXISTS ( SELECT 1
   FROM habits h
  WHERE ((h.id = "habit entries".habit_id) AND (h.user_id = ( SELECT auth.uid() AS uid))))))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."habit entries"'::regclass
      and polname = 'habit entries - update own'
  ) then
    execute $policy_sql$
  create policy "habit entries - update own"
  on public."habit entries"
  as permissive
  for update
  to "authenticated"
  using ((( SELECT auth.uid() AS uid) = user_id))
  with check ((( SELECT auth.uid() AS uid) = user_id))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."habit entries"'::regclass
      and polname = 'habit entries - user_id fixed on update'
  ) then
    execute $policy_sql$
  create policy "habit entries - user_id fixed on update"
  on public."habit entries"
  as restrictive
  for update
  to "authenticated"
  using ((( SELECT auth.uid() AS uid) = user_id))
  with check ((( SELECT auth.uid() AS uid) = user_id))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."memoryEngine"'::regclass
      and polname = 'memoryEngine_select_own'
  ) then
    execute $policy_sql$
  create policy "memoryEngine_select_own"
  on public."memoryEngine"
  as permissive
  for select
  to "authenticated"
  using ((user_id = auth.uid()))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."memoryEngine"'::regclass
      and polname = 'memoryengine_delete_own'
  ) then
    execute $policy_sql$
  create policy "memoryengine_delete_own"
  on public."memoryEngine"
  as permissive
  for delete
  to "authenticated"
  using ((user_id = auth.uid()))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."memoryEngine"'::regclass
      and polname = 'memoryengine_insert_own'
  ) then
    execute $policy_sql$
  create policy "memoryengine_insert_own"
  on public."memoryEngine"
  as permissive
  for insert
  to "authenticated"
  with check ((user_id = auth.uid()))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."memoryEngine"'::regclass
      and polname = 'memoryengine_update_own'
  ) then
    execute $policy_sql$
  create policy "memoryengine_update_own"
  on public."memoryEngine"
  as permissive
  for update
  to "authenticated"
  using ((user_id = auth.uid()))
  with check ((user_id = auth.uid()))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."milestones"'::regclass
      and polname = 'milestones_delete_own'
  ) then
    execute $policy_sql$
  create policy "milestones_delete_own"
  on public."milestones"
  as permissive
  for delete
  to "authenticated"
  using ((user_id = auth.uid()))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."milestones"'::regclass
      and polname = 'milestones_insert_own'
  ) then
    execute $policy_sql$
  create policy "milestones_insert_own"
  on public."milestones"
  as permissive
  for insert
  to "authenticated"
  with check ((user_id = auth.uid()))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."milestones"'::regclass
      and polname = 'milestones_select_own'
  ) then
    execute $policy_sql$
  create policy "milestones_select_own"
  on public."milestones"
  as permissive
  for select
  to "authenticated"
  using ((user_id = auth.uid()))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."milestones"'::regclass
      and polname = 'milestones_update_own'
  ) then
    execute $policy_sql$
  create policy "milestones_update_own"
  on public."milestones"
  as permissive
  for update
  to "authenticated"
  using ((user_id = auth.uid()))
  with check ((user_id = auth.uid()))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."notifications"'::regclass
      and polname = 'notifications - delete (user)'
  ) then
    execute $policy_sql$
  create policy "notifications - delete (user)"
  on public."notifications"
  as permissive
  for delete
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."notifications"'::regclass
      and polname = 'notifications - insert (user)'
  ) then
    execute $policy_sql$
  create policy "notifications - insert (user)"
  on public."notifications"
  as permissive
  for insert
  to "authenticated"
  with check ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."notifications"'::regclass
      and polname = 'notifications - select (user)'
  ) then
    execute $policy_sql$
  create policy "notifications - select (user)"
  on public."notifications"
  as permissive
  for select
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."notifications"'::regclass
      and polname = 'notifications - update (user)'
  ) then
    execute $policy_sql$
  create policy "notifications - update (user)"
  on public."notifications"
  as permissive
  for update
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
  with check ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."recurring_rules"'::regclass
      and polname = 'recurring_rules_delete_own'
  ) then
    execute $policy_sql$
  create policy "recurring_rules_delete_own"
  on public."recurring_rules"
  as permissive
  for delete
  to "authenticated"
  using ((( SELECT auth.uid() AS uid) = user_id))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."recurring_rules"'::regclass
      and polname = 'recurring_rules_insert_own'
  ) then
    execute $policy_sql$
  create policy "recurring_rules_insert_own"
  on public."recurring_rules"
  as permissive
  for insert
  to "authenticated"
  with check ((( SELECT auth.uid() AS uid) = user_id))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."recurring_rules"'::regclass
      and polname = 'recurring_rules_select_own'
  ) then
    execute $policy_sql$
  create policy "recurring_rules_select_own"
  on public."recurring_rules"
  as permissive
  for select
  to "authenticated"
  using ((( SELECT auth.uid() AS uid) = user_id))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."recurring_rules"'::regclass
      and polname = 'recurring_rules_update_own'
  ) then
    execute $policy_sql$
  create policy "recurring_rules_update_own"
  on public."recurring_rules"
  as permissive
  for update
  to "authenticated"
  using ((( SELECT auth.uid() AS uid) = user_id))
  with check ((( SELECT auth.uid() AS uid) = user_id))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."smart coach notes"'::regclass
      and polname = 'Smart coach notes: delete own'
  ) then
    execute $policy_sql$
  create policy "Smart coach notes: delete own"
  on public."smart coach notes"
  as permissive
  for delete
  to "authenticated"
  using ((( SELECT auth.uid() AS uid) = user_id))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."smart coach notes"'::regclass
      and polname = 'Smart coach notes: insert own'
  ) then
    execute $policy_sql$
  create policy "Smart coach notes: insert own"
  on public."smart coach notes"
  as permissive
  for insert
  to "authenticated"
  with check ((( SELECT auth.uid() AS uid) = user_id))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."smart coach notes"'::regclass
      and polname = 'Smart coach notes: select own'
  ) then
    execute $policy_sql$
  create policy "Smart coach notes: select own"
  on public."smart coach notes"
  as permissive
  for select
  to "authenticated"
  using ((( SELECT auth.uid() AS uid) = user_id))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."smart coach notes"'::regclass
      and polname = 'Smart coach notes: update own'
  ) then
    execute $policy_sql$
  create policy "Smart coach notes: update own"
  on public."smart coach notes"
  as permissive
  for update
  to "authenticated"
  using ((( SELECT auth.uid() AS uid) = user_id))
  with check ((( SELECT auth.uid() AS uid) = user_id))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."soul_maps"'::regclass
      and polname = 'soul_maps_delete_own'
  ) then
    execute $policy_sql$
  create policy "soul_maps_delete_own"
  on public."soul_maps"
  as permissive
  for delete
  to "authenticated"
  using ((( SELECT auth.uid() AS uid) = user_id))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."soul_maps"'::regclass
      and polname = 'soul_maps_insert_own'
  ) then
    execute $policy_sql$
  create policy "soul_maps_insert_own"
  on public."soul_maps"
  as permissive
  for insert
  to "authenticated"
  with check ((( SELECT auth.uid() AS uid) = user_id))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."soul_maps"'::regclass
      and polname = 'soul_maps_select_own'
  ) then
    execute $policy_sql$
  create policy "soul_maps_select_own"
  on public."soul_maps"
  as permissive
  for select
  to "authenticated"
  using ((( SELECT auth.uid() AS uid) = user_id))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."soul_maps"'::regclass
      and polname = 'soul_maps_update_own'
  ) then
    execute $policy_sql$
  create policy "soul_maps_update_own"
  on public."soul_maps"
  as permissive
  for update
  to "authenticated"
  using ((( SELECT auth.uid() AS uid) = user_id))
  with check ((( SELECT auth.uid() AS uid) = user_id))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."streaks"'::regclass
      and polname = 'streaks_delete_own'
  ) then
    execute $policy_sql$
  create policy "streaks_delete_own"
  on public."streaks"
  as permissive
  for delete
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."streaks"'::regclass
      and polname = 'streaks_insert_own'
  ) then
    execute $policy_sql$
  create policy "streaks_insert_own"
  on public."streaks"
  as permissive
  for insert
  to "authenticated"
  with check ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."streaks"'::regclass
      and polname = 'streaks_select_own'
  ) then
    execute $policy_sql$
  create policy "streaks_select_own"
  on public."streaks"
  as permissive
  for select
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."streaks"'::regclass
      and polname = 'streaks_update_own'
  ) then
    execute $policy_sql$
  create policy "streaks_update_own"
  on public."streaks"
  as permissive
  for update
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
  with check ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."subscriptions"'::regclass
      and polname = 'subscriptions_delete_server'
  ) then
    execute $policy_sql$
  create policy "subscriptions_delete_server"
  on public."subscriptions"
  as permissive
  for delete
  to "service_role"
  using (true)
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."subscriptions"'::regclass
      and polname = 'subscriptions_insert_server'
  ) then
    execute $policy_sql$
  create policy "subscriptions_insert_server"
  on public."subscriptions"
  as permissive
  for insert
  to "service_role"
  with check (true)
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."subscriptions"'::regclass
      and polname = 'subscriptions_select_own'
  ) then
    execute $policy_sql$
  create policy "subscriptions_select_own"
  on public."subscriptions"
  as permissive
  for select
  to "authenticated"
  using (((user_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM admin_users au
  WHERE (au.user_id = ( SELECT auth.uid() AS uid))))))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."subscriptions"'::regclass
      and polname = 'subscriptions_update_server'
  ) then
    execute $policy_sql$
  create policy "subscriptions_update_server"
  on public."subscriptions"
  as permissive
  for update
  to "service_role"
  using (true)
  with check (true)
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."sync_queue"'::regclass
      and polname = 'sync_queue_delete_own'
  ) then
    execute $policy_sql$
  create policy "sync_queue_delete_own"
  on public."sync_queue"
  as permissive
  for delete
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."sync_queue"'::regclass
      and polname = 'sync_queue_insert_own'
  ) then
    execute $policy_sql$
  create policy "sync_queue_insert_own"
  on public."sync_queue"
  as permissive
  for insert
  to "authenticated"
  with check ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."sync_queue"'::regclass
      and polname = 'sync_queue_select_own'
  ) then
    execute $policy_sql$
  create policy "sync_queue_select_own"
  on public."sync_queue"
  as permissive
  for select
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."sync_queue"'::regclass
      and polname = 'sync_queue_update_own'
  ) then
    execute $policy_sql$
  create policy "sync_queue_update_own"
  on public."sync_queue"
  as permissive
  for update
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
  with check ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."task_steps"'::regclass
      and polname = 'task_steps_delete_own'
  ) then
    execute $policy_sql$
  create policy "task_steps_delete_own"
  on public."task_steps"
  as permissive
  for delete
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."task_steps"'::regclass
      and polname = 'task_steps_insert_own'
  ) then
    execute $policy_sql$
  create policy "task_steps_insert_own"
  on public."task_steps"
  as permissive
  for insert
  to "authenticated"
  with check ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."task_steps"'::regclass
      and polname = 'task_steps_select_own'
  ) then
    execute $policy_sql$
  create policy "task_steps_select_own"
  on public."task_steps"
  as permissive
  for select
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."task_steps"'::regclass
      and polname = 'task_steps_update_own'
  ) then
    execute $policy_sql$
  create policy "task_steps_update_own"
  on public."task_steps"
  as permissive
  for update
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
  with check ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."timeline_events"'::regclass
      and polname = 'timeline_events_delete_own'
  ) then
    execute $policy_sql$
  create policy "timeline_events_delete_own"
  on public."timeline_events"
  as permissive
  for delete
  to "authenticated"
  using ((( SELECT auth.uid() AS uid) = user_id))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."timeline_events"'::regclass
      and polname = 'timeline_events_insert_own'
  ) then
    execute $policy_sql$
  create policy "timeline_events_insert_own"
  on public."timeline_events"
  as permissive
  for insert
  to "authenticated"
  with check ((( SELECT auth.uid() AS uid) = user_id))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."timeline_events"'::regclass
      and polname = 'timeline_events_select_own'
  ) then
    execute $policy_sql$
  create policy "timeline_events_select_own"
  on public."timeline_events"
  as permissive
  for select
  to "authenticated"
  using ((( SELECT auth.uid() AS uid) = user_id))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."timeline_events"'::regclass
      and polname = 'timeline_events_update_own'
  ) then
    execute $policy_sql$
  create policy "timeline_events_update_own"
  on public."timeline_events"
  as permissive
  for update
  to "authenticated"
  using ((( SELECT auth.uid() AS uid) = user_id))
  with check ((( SELECT auth.uid() AS uid) = user_id))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."user_achievements"'::regclass
      and polname = 'user_achievements_delete_own'
  ) then
    execute $policy_sql$
  create policy "user_achievements_delete_own"
  on public."user_achievements"
  as permissive
  for delete
  to "authenticated"
  using ((( SELECT auth.uid() AS uid) = user_id))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."user_achievements"'::regclass
      and polname = 'user_achievements_insert_own'
  ) then
    execute $policy_sql$
  create policy "user_achievements_insert_own"
  on public."user_achievements"
  as permissive
  for insert
  to "authenticated"
  with check ((( SELECT auth.uid() AS uid) = user_id))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."user_achievements"'::regclass
      and polname = 'user_achievements_select_own'
  ) then
    execute $policy_sql$
  create policy "user_achievements_select_own"
  on public."user_achievements"
  as permissive
  for select
  to "authenticated"
  using ((( SELECT auth.uid() AS uid) = user_id))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."user_achievements"'::regclass
      and polname = 'user_achievements_update_own'
  ) then
    execute $policy_sql$
  create policy "user_achievements_update_own"
  on public."user_achievements"
  as permissive
  for update
  to "authenticated"
  using ((( SELECT auth.uid() AS uid) = user_id))
  with check ((( SELECT auth.uid() AS uid) = user_id))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."user_devices"'::regclass
      and polname = 'User devices delete'
  ) then
    execute $policy_sql$
  create policy "User devices delete"
  on public."user_devices"
  as permissive
  for delete
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."user_devices"'::regclass
      and polname = 'User devices insert'
  ) then
    execute $policy_sql$
  create policy "User devices insert"
  on public."user_devices"
  as permissive
  for insert
  to "authenticated"
  with check ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."user_devices"'::regclass
      and polname = 'User devices read'
  ) then
    execute $policy_sql$
  create policy "User devices read"
  on public."user_devices"
  as permissive
  for select
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."user_devices"'::regclass
      and polname = 'User devices update'
  ) then
    execute $policy_sql$
  create policy "User devices update"
  on public."user_devices"
  as permissive
  for update
  to "authenticated"
  using ((user_id = ( SELECT auth.uid() AS uid)))
  with check ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

do $policy$
begin
  if not exists (
    select 1
    from pg_policy
    where polrelid = 'public."webhook_events"'::regclass
      and polname = 'webhook insert own'
  ) then
    execute $policy_sql$
  create policy "webhook insert own"
  on public."webhook_events"
  as permissive
  for insert
  to "authenticated"
  with check ((user_id = ( SELECT auth.uid() AS uid)))
    $policy_sql$;
  end if;
end;
$policy$;

-- Restore hosted triggers without replacing existing definitions.
do $trigger$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public."achievements"'::regclass
      and tgname = 'set_achievements_updated_at'
      and not tgisinternal
  ) then
    execute $trigger_sql$CREATE TRIGGER set_achievements_updated_at BEFORE UPDATE ON achievements FOR EACH ROW EXECUTE FUNCTION set_updated_at()$trigger_sql$;
  end if;
end;
$trigger$;

do $trigger$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public."app_announcements"'::regclass
      and tgname = 'set_app_announcements_updated_at'
      and not tgisinternal
  ) then
    execute $trigger_sql$CREATE TRIGGER set_app_announcements_updated_at BEFORE UPDATE ON app_announcements FOR EACH ROW EXECUTE FUNCTION set_updated_at()$trigger_sql$;
  end if;
end;
$trigger$;

do $trigger$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public."app_events"'::regclass
      and tgname = 'trg_sync_app_events_legacy'
      and not tgisinternal
  ) then
    execute $trigger_sql$CREATE TRIGGER trg_sync_app_events_legacy BEFORE INSERT OR UPDATE ON app_events FOR EACH ROW EXECUTE FUNCTION sync_app_events_legacy_fields()$trigger_sql$;
  end if;
end;
$trigger$;

do $trigger$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public."core_values"'::regclass
      and tgname = 'trg_set_updated_at'
      and not tgisinternal
  ) then
    execute $trigger_sql$CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON core_values FOR EACH ROW EXECUTE FUNCTION set_updated_at()$trigger_sql$;
  end if;
end;
$trigger$;

do $trigger$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public."entitlement_events"'::regclass
      and tgname = 'set_entitlement_events_updated_at'
      and not tgisinternal
  ) then
    execute $trigger_sql$CREATE TRIGGER set_entitlement_events_updated_at BEFORE UPDATE ON entitlement_events FOR EACH ROW EXECUTE FUNCTION set_updated_at()$trigger_sql$;
  end if;
end;
$trigger$;

do $trigger$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public."feedback_reports"'::regclass
      and tgname = 'set_feedback_reports_updated_at'
      and not tgisinternal
  ) then
    execute $trigger_sql$CREATE TRIGGER set_feedback_reports_updated_at BEFORE UPDATE ON feedback_reports FOR EACH ROW EXECUTE FUNCTION set_updated_at()$trigger_sql$;
  end if;
end;
$trigger$;

do $trigger$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public."focus_sessions"'::regclass
      and tgname = 'set_focus_sessions_updated_at'
      and not tgisinternal
  ) then
    execute $trigger_sql$CREATE TRIGGER set_focus_sessions_updated_at BEFORE UPDATE ON focus_sessions FOR EACH ROW EXECUTE FUNCTION set_updated_at()$trigger_sql$;
  end if;
end;
$trigger$;

do $trigger$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public."goal_checkins"'::regclass
      and tgname = 'set_goal_checkins_updated_at'
      and not tgisinternal
  ) then
    execute $trigger_sql$CREATE TRIGGER set_goal_checkins_updated_at BEFORE UPDATE ON goal_checkins FOR EACH ROW EXECUTE FUNCTION set_updated_at()$trigger_sql$;
  end if;
end;
$trigger$;

do $trigger$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public."memoryEngine"'::regclass
      and tgname = 'trg_set_updated_at'
      and not tgisinternal
  ) then
    execute $trigger_sql$CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON "memoryEngine" FOR EACH ROW EXECUTE FUNCTION set_updated_at()$trigger_sql$;
  end if;
end;
$trigger$;

do $trigger$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public."milestones"'::regclass
      and tgname = 'trg_set_updated_at'
      and not tgisinternal
  ) then
    execute $trigger_sql$CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON milestones FOR EACH ROW EXECUTE FUNCTION set_updated_at()$trigger_sql$;
  end if;
end;
$trigger$;

do $trigger$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public."notifications"'::regclass
      and tgname = 'trg_set_updated_at'
      and not tgisinternal
  ) then
    execute $trigger_sql$CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON notifications FOR EACH ROW EXECUTE FUNCTION set_updated_at()$trigger_sql$;
  end if;
end;
$trigger$;

do $trigger$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public."recurring_rules"'::regclass
      and tgname = 'set_recurring_rules_updated_at'
      and not tgisinternal
  ) then
    execute $trigger_sql$CREATE TRIGGER set_recurring_rules_updated_at BEFORE UPDATE ON recurring_rules FOR EACH ROW EXECUTE FUNCTION set_updated_at()$trigger_sql$;
  end if;
end;
$trigger$;

do $trigger$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public."soul_maps"'::regclass
      and tgname = 'soul_maps_set_updated_at'
      and not tgisinternal
  ) then
    execute $trigger_sql$CREATE TRIGGER soul_maps_set_updated_at BEFORE UPDATE ON soul_maps FOR EACH ROW EXECUTE FUNCTION set_updated_at()$trigger_sql$;
  end if;
end;
$trigger$;

do $trigger$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public."soul_maps"'::regclass
      and tgname = 'trg_set_updated_at'
      and not tgisinternal
  ) then
    execute $trigger_sql$CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON soul_maps FOR EACH ROW EXECUTE FUNCTION set_updated_at()$trigger_sql$;
  end if;
end;
$trigger$;

do $trigger$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public."streaks"'::regclass
      and tgname = 'set_streaks_updated_at'
      and not tgisinternal
  ) then
    execute $trigger_sql$CREATE TRIGGER set_streaks_updated_at BEFORE UPDATE ON streaks FOR EACH ROW EXECUTE FUNCTION set_updated_at()$trigger_sql$;
  end if;
end;
$trigger$;

do $trigger$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public."subscriptions"'::regclass
      and tgname = 'set_subscriptions_updated_at'
      and not tgisinternal
  ) then
    execute $trigger_sql$CREATE TRIGGER set_subscriptions_updated_at BEFORE UPDATE ON subscriptions FOR EACH ROW EXECUTE FUNCTION set_updated_at()$trigger_sql$;
  end if;
end;
$trigger$;

do $trigger$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public."sync_queue"'::regclass
      and tgname = 'set_sync_queue_updated_at'
      and not tgisinternal
  ) then
    execute $trigger_sql$CREATE TRIGGER set_sync_queue_updated_at BEFORE UPDATE ON sync_queue FOR EACH ROW EXECUTE FUNCTION set_updated_at()$trigger_sql$;
  end if;
end;
$trigger$;

do $trigger$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public."task_steps"'::regclass
      and tgname = 'set_task_steps_updated_at'
      and not tgisinternal
  ) then
    execute $trigger_sql$CREATE TRIGGER set_task_steps_updated_at BEFORE UPDATE ON task_steps FOR EACH ROW EXECUTE FUNCTION set_updated_at()$trigger_sql$;
  end if;
end;
$trigger$;

do $trigger$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public."timeline_events"'::regclass
      and tgname = 'timeline_events_set_updated_at'
      and not tgisinternal
  ) then
    execute $trigger_sql$CREATE TRIGGER timeline_events_set_updated_at BEFORE UPDATE ON timeline_events FOR EACH ROW EXECUTE FUNCTION set_updated_at()$trigger_sql$;
  end if;
end;
$trigger$;

do $trigger$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public."timeline_events"'::regclass
      and tgname = 'trg_set_updated_at'
      and not tgisinternal
  ) then
    execute $trigger_sql$CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON timeline_events FOR EACH ROW EXECUTE FUNCTION set_updated_at()$trigger_sql$;
  end if;
end;
$trigger$;

do $trigger$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public."user_achievements"'::regclass
      and tgname = 'set_user_achievements_updated_at'
      and not tgisinternal
  ) then
    execute $trigger_sql$CREATE TRIGGER set_user_achievements_updated_at BEFORE UPDATE ON user_achievements FOR EACH ROW EXECUTE FUNCTION set_updated_at()$trigger_sql$;
  end if;
end;
$trigger$;

do $trigger$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public."user_devices"'::regclass
      and tgname = 'set_user_devices_updated_at'
      and not tgisinternal
  ) then
    execute $trigger_sql$CREATE TRIGGER set_user_devices_updated_at BEFORE UPDATE ON user_devices FOR EACH ROW EXECUTE FUNCTION set_updated_at()$trigger_sql$;
  end if;
end;
$trigger$;

-- The hosted schema contains two identical updated_at triggers on these
-- tables. Keep the table-specific trigger and remove the duplicate legacy
-- trigger so every UPDATE executes the timestamp function exactly once.
drop trigger if exists trg_set_updated_at on public.soul_maps;
drop trigger if exists trg_set_updated_at on public.timeline_events;

-- These four hosted policies were created TO PUBLIC. Their auth.uid()
-- predicates denied ordinary anonymous callers, but targeting authenticated
-- explicitly prevents future auth-mode changes from widening the surface.
drop policy if exists "notifications - delete (user)" on public.notifications;
create policy "notifications - delete (user)"
on public.notifications
for delete
to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "notifications - insert (user)" on public.notifications;
create policy "notifications - insert (user)"
on public.notifications
for insert
to authenticated
with check (user_id = (select auth.uid()));

drop policy if exists "notifications - select (user)" on public.notifications;
create policy "notifications - select (user)"
on public.notifications
for select
to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "notifications - update (user)" on public.notifications;
create policy "notifications - update (user)"
on public.notifications
for update
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

-- Preserve the hosted Realtime publication membership when that
-- publication exists in the target Supabase environment.
do $publication$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1
       from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'core_values'
     ) then
    execute $publication_sql$alter publication supabase_realtime add table public."core_values"$publication_sql$;
  end if;
end;
$publication$;

do $publication$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1
       from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'habit entries'
     ) then
    execute $publication_sql$alter publication supabase_realtime add table public."habit entries"$publication_sql$;
  end if;
end;
$publication$;

do $publication$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1
       from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'memoryEngine'
     ) then
    execute $publication_sql$alter publication supabase_realtime add table public."memoryEngine"$publication_sql$;
  end if;
end;
$publication$;

do $publication$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1
       from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'milestones'
     ) then
    execute $publication_sql$alter publication supabase_realtime add table public."milestones"$publication_sql$;
  end if;
end;
$publication$;

do $publication$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1
       from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'notifications'
     ) then
    execute $publication_sql$alter publication supabase_realtime add table public."notifications"$publication_sql$;
  end if;
end;
$publication$;

do $publication$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1
       from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'smart coach notes'
     ) then
    execute $publication_sql$alter publication supabase_realtime add table public."smart coach notes"$publication_sql$;
  end if;
end;
$publication$;

do $publication$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1
       from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'soul_maps'
     ) then
    execute $publication_sql$alter publication supabase_realtime add table public."soul_maps"$publication_sql$;
  end if;
end;
$publication$;

do $publication$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1
       from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'timeline_events'
     ) then
    execute $publication_sql$alter publication supabase_realtime add table public."timeline_events"$publication_sql$;
  end if;
end;
$publication$;

-- Replace historical broad Data API grants with the minimum policy-backed
-- authenticated DML surface. service_role keeps DML for trusted backend
-- cleanup and administration, but not TRUNCATE/REFERENCES/TRIGGER/MAINTAIN.
revoke all on table public."achievements" from public, anon, authenticated, service_role;
grant select on table public."achievements" to authenticated;
grant select, insert, update, delete on table public."achievements" to service_role;
revoke all on table public."admin_users" from public, anon, authenticated, service_role;
grant select on table public."admin_users" to authenticated;
grant select, insert, update, delete on table public."admin_users" to service_role;
revoke all on table public."app_announcements" from public, anon, authenticated, service_role;
grant select on table public."app_announcements" to authenticated;
grant select, insert, update, delete on table public."app_announcements" to service_role;
revoke all on table public."app_events" from public, anon, authenticated, service_role;
grant delete, insert, select, update on table public."app_events" to authenticated;
grant select, insert, update, delete on table public."app_events" to service_role;
revoke all on table public."core_values" from public, anon, authenticated, service_role;
grant delete, insert, select, update on table public."core_values" to authenticated;
grant select, insert, update, delete on table public."core_values" to service_role;
revoke all on table public."entitlement_events" from public, anon, authenticated, service_role;
grant delete, insert, select, update on table public."entitlement_events" to authenticated;
grant select, insert, update, delete on table public."entitlement_events" to service_role;
revoke all on table public."feedback_reports" from public, anon, authenticated, service_role;
grant delete, insert, select, update on table public."feedback_reports" to authenticated;
grant select, insert, update, delete on table public."feedback_reports" to service_role;
revoke all on table public."focus_sessions" from public, anon, authenticated, service_role;
grant delete, insert, select, update on table public."focus_sessions" to authenticated;
grant select, insert, update, delete on table public."focus_sessions" to service_role;
revoke all on table public."goal_checkins" from public, anon, authenticated, service_role;
grant delete, insert, select, update on table public."goal_checkins" to authenticated;
grant select, insert, update, delete on table public."goal_checkins" to service_role;
revoke all on table public."habit entries" from public, anon, authenticated, service_role;
grant delete, insert, select, update on table public."habit entries" to authenticated;
grant select, insert, update, delete on table public."habit entries" to service_role;
revoke all on table public."memoryEngine" from public, anon, authenticated, service_role;
grant delete, insert, select, update on table public."memoryEngine" to authenticated;
grant select, insert, update, delete on table public."memoryEngine" to service_role;
revoke all on table public."milestones" from public, anon, authenticated, service_role;
grant delete, insert, select, update on table public."milestones" to authenticated;
grant select, insert, update, delete on table public."milestones" to service_role;
revoke all on table public."notifications" from public, anon, authenticated, service_role;
grant delete, insert, select, update on table public."notifications" to authenticated;
grant select, insert, update, delete on table public."notifications" to service_role;
revoke all on table public."recurring_rules" from public, anon, authenticated, service_role;
grant delete, insert, select, update on table public."recurring_rules" to authenticated;
grant select, insert, update, delete on table public."recurring_rules" to service_role;
revoke all on table public."smart coach notes" from public, anon, authenticated, service_role;
grant delete, insert, select, update on table public."smart coach notes" to authenticated;
grant select, insert, update, delete on table public."smart coach notes" to service_role;
revoke all on table public."soul_maps" from public, anon, authenticated, service_role;
grant delete, insert, select, update on table public."soul_maps" to authenticated;
grant select, insert, update, delete on table public."soul_maps" to service_role;
revoke all on table public."streaks" from public, anon, authenticated, service_role;
grant delete, insert, select, update on table public."streaks" to authenticated;
grant select, insert, update, delete on table public."streaks" to service_role;
revoke all on table public."subscriptions" from public, anon, authenticated, service_role;
grant select on table public."subscriptions" to authenticated;
grant select, insert, update, delete on table public."subscriptions" to service_role;
revoke all on table public."sync_queue" from public, anon, authenticated, service_role;
grant delete, insert, select, update on table public."sync_queue" to authenticated;
grant select, insert, update, delete on table public."sync_queue" to service_role;
revoke all on table public."task_steps" from public, anon, authenticated, service_role;
grant delete, insert, select, update on table public."task_steps" to authenticated;
grant select, insert, update, delete on table public."task_steps" to service_role;
revoke all on table public."timeline_events" from public, anon, authenticated, service_role;
grant delete, insert, select, update on table public."timeline_events" to authenticated;
grant select, insert, update, delete on table public."timeline_events" to service_role;
revoke all on table public."user_achievements" from public, anon, authenticated, service_role;
grant delete, insert, select, update on table public."user_achievements" to authenticated;
grant select, insert, update, delete on table public."user_achievements" to service_role;
revoke all on table public."user_devices" from public, anon, authenticated, service_role;
grant delete, insert, select, update on table public."user_devices" to authenticated;
grant select, insert, update, delete on table public."user_devices" to service_role;
revoke all on table public."webhook_events" from public, anon, authenticated, service_role;
grant insert on table public."webhook_events" to authenticated;
grant select, insert, update, delete on table public."webhook_events" to service_role;
