# Staging Object Inventory Review

**Read-only review. No migration, deployment, seed, or remote query was run for this report.**

## Scope and Evidence

- Confirmed target: `RETIRED_STAGING_PROJECT`.
- `npx supabase migration list` shows local migrations with blank Remote values.
- Read-only existence audit recorded `auth_user_count = 2`, `storage_bucket_count = 0`, and `storage_object_count = 0`.
- No expected ChronoSpark app tables were evident in the audit output.
- Function discovery output reported `NOT_FOUND` for every expected ChronoSpark RPC.
- The audit reported only default Supabase/platform and system objects, plus the reviewed untracked helper `public.rls_auto_enable`.

This evidence does not establish that staging is disposable: the two Auth users must be confirmed as intentional staging test users or disposable.

## Classification Rules

- `SAFE_TO_REPLACE`: the exact expected object is confirmed absent, with no conflicting object of that exact name in the inspected scope.
- `MANUAL_OBJECT_FOUND`: a non-migration-tracked or conflicting staging object is confirmed present.
- `NEEDS_COMPATIBILITY_REVIEW`: evidence is missing, incomplete, or shows an existing object whose compatibility must be reviewed.

## Existing Tables By Schema

| Schema | Objects | Evidence | Classification |
| --- | --- | --- | --- |
| `public` | Expected ChronoSpark core, monetization, and rate-limit tables | No expected ChronoSpark app tables were evident in the audit output. | `ABSENT` |
| Default Supabase/platform and system schemas | Platform objects | Present as expected platform objects. | `IGNORE_SYSTEM_OBJECTS` |
| `public` | `rls_auto_enable` helper | Reviewed untracked helper that enables RLS on newly created public tables. | `REVIEWED_NON_CONFLICTING_UNTRACKED_HELPER` |

## Existing Functions By Schema

| Schema | Functions | Evidence | Classification |
| --- | --- | --- | --- |
| All non-system schemas | `apply_verified_purchase`, `consume_ai_proxy_rate_limit`, `consume_monetization_credits`, `ensure_monetization_wallet`, `ensure_profile_for_current_user`, `get_global_metrics`, `grant_monetization_credits`, `handle_new_user`, `reset_monetization_allowance` | [function_discovery.sql](function_discovery.sql) returned `NOT_FOUND` for every expected function. | `ABSENT` |
| Default Supabase/platform and system schemas | Platform functions | Present as expected platform objects. | `IGNORE_SYSTEM_OBJECTS` |
| `public` | `rls_auto_enable` | Present; no tracked migration references it. | `REVIEWED_NON_CONFLICTING_UNTRACKED_HELPER` |

## Existing Buckets and Storage Objects

| Scope | Evidence | Classification |
| --- | --- | --- |
| Storage buckets | `0` | `SAFE_EMPTY` |
| `storage.objects` | `0` | `SAFE_EMPTY` |

## Existing Auth Users Count

| Scope | Evidence | Classification |
| --- | --- | --- |
| `auth.users` | `2` | `NEEDS_HUMAN_CONFIRMATION` - confirm both are intentional staging test users or disposable. |

## Existing Policies

| Scope | Evidence | Classification |
| --- | --- | --- |
| Expected application tables | [schema_discovery.sql](schema_discovery.sql) can report policy counts and `auth.uid()` signals, but no current output is captured. | `NEEDS_COMPATIBILITY_REVIEW` |
| Other tables and Storage | No policy inventory output captured. | `NEEDS_COMPATIBILITY_REVIEW` |

## Existing Triggers

| Scope | Evidence | Classification |
| --- | --- | --- |
| Non-system schemas | No trigger inventory output captured. | `NEEDS_COMPATIBILITY_REVIEW` |

## Existing Views

| Scope | Evidence | Classification |
| --- | --- | --- |
| Non-system schemas | No view inventory output captured. | `NEEDS_COMPATIBILITY_REVIEW` |

## Existing Extensions

| Scope | Evidence | Classification |
| --- | --- | --- |
| Database extensions | No extension inventory output captured. | `NEEDS_COMPATIBILITY_REVIEW` |

## Untracked Helper Review

`public.rls_auto_enable()` has been reviewed. It is an untracked `SECURITY DEFINER` event-trigger function with `search_path` set to `pg_catalog`. For new public tables created by `CREATE TABLE`, `CREATE TABLE AS`, or `SELECT INTO`, it enables RLS; it skips system and temporary schemas and logs failures without throwing. No tracked migration creates, references, depends on, or creates a same-named function. This helper is security-positive and non-conflicting with the tracked migration chain. Leave it in place; no database change is authorized by this review.

## Review Outcome

- `SAFE_EMPTY`: Storage has zero buckets and zero objects.
- `ABSENT`: expected ChronoSpark app tables and RPC functions.
- `NEEDS_HUMAN_CONFIRMATION`: the two Auth users.
- `REVIEWED_NON_CONFLICTING_UNTRACKED_HELPER`: `public.rls_auto_enable`.
- `IGNORE_SYSTEM_OBJECTS`: default Supabase/platform and system objects.

Migration application remains blocked until the two Auth users are confirmed disposable, the destructive metrics migration is accepted as safe for the absent target table, and a human explicitly approves the staging application.
