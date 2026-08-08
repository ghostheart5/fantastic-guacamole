# ChronoSpark — Supabase Audit

**Date:** 2026-08-06
**Project:** `ghostheart5's Project` (ref redacted) · `aws-1-us-west-2`
**Postgres:** 17.6.1.141 · **GoTrue:** v2.192.0 · **PostgREST:** v14.5 · **Storage:** v1.65.1 · **CLI:** v2.109.1
**Migrations:** 5 · **Edge functions:** 2

---

## Summary

The Supabase layer is mostly well-constructed. Four of five tables/buckets use correct owner-scoped RLS with `revoke all` before explicit grants — the disciplined pattern. Both edge functions verify JWTs, keep provider secrets server-side, cap payload sizes, and return generic error strings.

**One policy breaks the pattern and leaks every user's data to every other user.** That is the single critical finding in this entire audit.

| ID | Severity | Finding |
|---|---|---|
| SUP-01 | **CRITICAL** | `user_daily_metrics` SELECT uses `using (true)` |
| SUP-02 | HIGH | Metrics PK omits `user_id`; UPDATE policy allows claiming orphan rows |
| SUP-03 | MEDIUM | Edge-function rate limiting is per-isolate and leaks memory |
| SUP-04 | MEDIUM | AI proxy accepts a client-supplied system prompt |
| SUP-05 | MEDIUM | `handle_new_user` swallows all exceptions — silent profile loss |
| SUP-06 | MEDIUM | No timeouts on any upstream `fetch` |
| SUP-07 | LOW | `security definer` uses `search_path = public`, not `''` |
| SUP-08 | LOW | `purchase_bindings` race → spurious denial (PK prevents double-bind) |
| SUP-09 | LOW | Empty migration file committed |
| SUP-10 | LOW | Inconsistent migration naming (12-digit vs 14-digit) |
| SUP-11 | LOW | `supabase/.temp/` committed to git |
| SUP-12 | LOW | Dead no-op `update` statement in a migration |
| SUP-13 | INFO | No DELETE grant on `user_daily_metrics` — GDPR erasure gap |

---

## A. Row Level Security matrix

| Table / bucket | RLS | anon | SELECT | INSERT | UPDATE | DELETE | Verdict |
|---|---|---|---|---|---|---|---|
| `public.profiles` | ✅ | revoked | `auth.uid() = id` | `auth.uid() = id` | `auth.uid() = id` | none | ✅ **Correct** |
| `public.purchase_bindings` | ✅ | revoked | `auth.uid() = user_id` | `auth.uid() = user_id` | `auth.uid() = user_id` | `auth.uid() = user_id` | ✅ **Correct** |
| `public.user_daily_metrics` | ✅ | revoked | **`using (true)`** | `auth.uid() = user_id` | `user_id is null or auth.uid() = user_id` | none | ❌ **BROKEN** |
| `storage.objects` (`chronospark-sync`) | ✅ | n/a | prefix = `auth.uid()` | prefix = `auth.uid()` | prefix = `auth.uid()` | prefix = `auth.uid()` | ✅ **Correct** |

Every table enables RLS and revokes `anon` before granting to `authenticated`. No table has RLS enabled with zero policies (which would silently deny all access), and no table is left without RLS (which would expose it to the anon key).

---

## SUP-01 · CRITICAL · Cross-tenant read on `user_daily_metrics`

**File:** `supabase/migrations/202607110002_data_policies.sql:47-52`

```sql
drop policy if exists "user_daily_metrics_select_authenticated" on public.user_daily_metrics;
create policy "user_daily_metrics_select_authenticated"
on public.user_daily_metrics
for select
to authenticated
using (true);
```

**Evidence:** The predicate is the literal `true` — no `auth.uid()` comparison. Compare against the sibling policies in the same file (`user_daily_metrics_insert_own`, line 59: `with check (auth.uid() = user_id)`) and the equivalents in `profiles` and `purchase_bindings`, all of which correctly scope to the owner. The policy name itself says `_authenticated` rather than `_own`, suggesting "any authenticated user" was intentional at write time — but the table stores per-user behavioural data, so it should not be.

**Impact:** Any authenticated user can read the entire table:

```
GET /rest/v1/user_daily_metrics?select=*
Authorization: Bearer <any valid user JWT>
apikey: <anon key — publishable by design>
```

Returns every row for every user: `user_id`, `device_id`, `date`, `tasks_created`, `tasks_completed`, `momentum_peak`. That is a longitudinal behavioural profile of the whole user base, keyed to stable user and device identifiers.

**Production risk:**
- Cross-tenant data breach, exploitable by anyone who can sign up. If signups are open, the attacker needs no relationship to the app at all.
- The anon key is publishable by design and is expected to be extractable from the client — the security model assumes RLS is the boundary. Here it is not.
- Reportable under GDPR Art. 33 (72-hour notification) and analogous CCPA provisions.
- `device_id` enables cross-referencing users to devices, widening the impact beyond aggregate counts.

**Recommended fix:**

```sql
drop policy if exists "user_daily_metrics_select_authenticated" on public.user_daily_metrics;
create policy "user_daily_metrics_select_own"
on public.user_daily_metrics
for select
to authenticated
using (auth.uid() = user_id);
```

If a leaderboard or benchmark genuinely needs cross-user aggregates, expose it as a `security definer` function returning only aggregates (never row-level data), with `set search_path = ''` — do not relax the table policy.

**Verify afterwards:** sign in as user A, request the table, and confirm only A's rows return.

---

## SUP-02 · HIGH · Primary key omits the owner; UPDATE policy allows claiming orphans

**File:** `supabase/migrations/202607110002_data_policies.sql:1-11, 61-67`

```sql
create table if not exists public.user_daily_metrics (
  device_id text not null,
  date date not null,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  ...
  primary key (device_id, date)
);
...
create policy "user_daily_metrics_update_own"
on public.user_daily_metrics
for update
to authenticated
using (user_id is null or auth.uid() = user_id)
with check (auth.uid() = user_id);
```

**Two compounding defects:**

1. **PK is `(device_id, date)` with no `user_id`.** `device_id` is supplied by the client. Two legitimate users sharing a device collide on the same PK. More seriously, a malicious client can submit another user's `device_id` to occupy their PK slot, and the victim's inserts then fail — a targeted denial of service on their metrics.

2. **UPDATE `using (user_id is null or auth.uid() = user_id)`** lets any authenticated user update any row whose `user_id` is NULL, and the `with check` then stamps it to the attacker. Rows can be NULL because line 14 adds the column as nullable (`add column if not exists user_id uuid`) for tables that pre-date the migration.

**SUP-01 makes both practical** — the `using (true)` SELECT hands the attacker a complete list of every `device_id` to target.

**Fix:**

```sql
-- Backfill or delete NULL-owner rows first, then:
alter table public.user_daily_metrics alter column user_id set not null;
alter table public.user_daily_metrics drop constraint user_daily_metrics_pkey;
alter table public.user_daily_metrics add primary key (user_id, device_id, date);

create policy "user_daily_metrics_update_own"
on public.user_daily_metrics for update to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);
```

---

## SUP-03 · MEDIUM · Rate limiting does not survive the execution model

**Files:** `supabase/functions/ai-proxy/index.ts:11, 33-40` · `supabase/functions/verify-receipt/index.ts:18, 40-47`

```ts
const requestWindows = new Map<string, number[]>();

function withinRateLimit(userId: string): boolean {
  const now = Date.now();
  const recent = (requestWindows.get(userId) ?? []).filter((time) => now - time < 60_000);
  if (recent.length >= 20) return false;   // 10 in verify-receipt
  recent.push(now);
  requestWindows.set(userId, recent);
  return true;
}
```

**Impact:** Supabase Edge Functions are stateless and scale horizontally across isolates. Each isolate has its own `Map`, and every cold start resets it. The effective limit is *per-isolate*, not per-user — an attacker spreading load across isolates multiplies their quota, and a burst after a scale-up event bypasses it almost entirely.

Separately, entries are never evicted. `requestWindows` grows monotonically with distinct user IDs for the isolate's lifetime — a slow memory leak that also degrades the `.filter()` on every call.

**Production risk:** On `ai-proxy` this is a direct financial exposure — the ceiling on the owner's Anthropic spend is softer than the code implies. On `verify-receipt` it weakens brute-force resistance against purchase-token probing.

**Fix:** Move the window to shared state.

```sql
create table public.rate_limits (
  user_id uuid not null,
  bucket text not null,
  window_start timestamptz not null,
  count int not null default 0,
  primary key (user_id, bucket, window_start)
);
```

Upsert with `on conflict … do update set count = rate_limits.count + 1` and reject when the count exceeds the limit. Upstash Redis is the lower-latency alternative. At minimum, delete map entries whose window has fully expired.

---

## SUP-04 · MEDIUM · Client controls the AI system prompt

**File:** `supabase/functions/ai-proxy/index.ts:49-57, 91-97, 132`

```ts
interface ProxyRequest {
  prompt?: string;
  message?: string;
  history?: Array<{ role: "user" | "assistant"; content: string }>;
  system?: string;                       // ← client-supplied
  model?: string;
  maxTokens?: number;
  context?: Record<string, unknown>;     // ← accepted, never used
}
...
if (system) anthropicBody.system = system;
```

**Impact:** Any authenticated user can replace the system prompt entirely. The proxy becomes a general-purpose Anthropic endpoint billed to the app owner, with the app's persona, safety framing, and output-shape constraints all bypassable. Combined with SUP-03's weak rate limiting, this is the most plausible cost-abuse path in the system.

Note the model is handled **correctly** by contrast — `model` is declared in `ProxyRequest` but line 128 always uses the server-side `DEFAULT_MODEL`, so a client cannot select an expensive model. The `system` passthrough is the inconsistency.

**Fix:** Remove `system` from `ProxyRequest` and compose it server-side:

```ts
const SYSTEM_PROMPT = "You are ChronoSpark's planning assistant. …";
const anthropicBody = { model: DEFAULT_MODEL, max_tokens: …, system: SYSTEM_PROMPT, messages };
```

If per-mode variation is needed, accept a `mode` enum and map it to a server-side template. Also drop the unused `model` and `context` fields — an interface that accepts fields it ignores misleads callers.

---

## SUP-05 · MEDIUM · `handle_new_user` swallows every exception

**File:** `supabase/migrations/20260712143000_resilient_handle_new_user.sql:8-23`

```sql
begin
  insert into public.profiles (id, email, full_name, avatar_url)
  values (...)
  on conflict (id) do update set ...;
exception
  when others then
    raise warning 'handle_new_user failed for user %, error: %', new.id, sqlerrm;
end;
```

This migration supersedes the stricter version in `202607110001_profiles.sql:53-73` via `create or replace`. The intent is sound — a failing trigger on `auth.users` would otherwise **block signup entirely**, which is a worse failure. But `when others` catches everything and downgrades it to a warning.

**Impact:** If the profile insert fails for any reason (constraint violation, type error, a future schema change), the user account is created in `auth.users` with **no corresponding `profiles` row**. The app then holds a session for a user with no profile. Whether that surfaces as a crash, an empty UI, or silent degradation depends on client null-handling. `raise warning` writes to Postgres logs, which nothing monitors by default — the failure is invisible until a user complains.

**Production risk:** Silent data inconsistency in the identity layer, with no alerting. Recovery is possible client-side because `profiles_insert_own` permits the user to insert their own row — but only if the app actually implements that fallback.

**Fix:** Keep the non-blocking behaviour but make it observable and recoverable:
- Narrow the handler to the specific exceptions worth tolerating rather than `when others`.
- Write failures to a `profile_creation_failures` table and alert on it.
- Ensure the client performs an upsert-own-profile on first authenticated launch, so a missed trigger self-heals.

---

## SUP-06 · MEDIUM · No timeouts on upstream calls

**Files:** `ai-proxy/index.ts:25, 134` · `verify-receipt/index.ts:32, 155, 217`

No `fetch` in either function sets a timeout — not the Anthropic Messages call, the Google OAuth token exchange, the Play Developer API call, or the `/auth/v1/user` JWT verification. A slow or hanging upstream holds the invocation until the platform timeout, consuming a concurrency slot.

**Fix:**

```ts
const res = await fetch(ANTHROPIC_API, { ..., signal: AbortSignal.timeout(30_000) });
```

Catch `TimeoutError` and return 504. Use a shorter budget (~5s) for the `/auth/v1/user` check, since it is on the hot path of every request.

---

## SUP-07 · LOW · `security definer` pins `search_path = public`, not `''`

**Files:** `202607110001_profiles.sql:56-57` · `20260712143000_resilient_handle_new_user.sql:4-5`

```sql
security definer
set search_path = public
```

The hardened form is `set search_path = ''` with fully-qualified object names, which eliminates search-path hijacking entirely.

**Why this is LOW here, not CRITICAL:** two mitigations already hold. All object references inside the function are fully qualified (`public.profiles`, `public.set_profiles_updated_at`), and the project runs **Postgres 17.6.1**, where `CREATE` on the `public` schema is revoked from `PUBLIC` by default — so an unprivileged user cannot plant a shadowing object. The setting is pinned rather than inherited, which is the important half.

**Fix:** `set search_path = ''`. The function body already qualifies every name, so this is a one-word change with no other edits.

---

## SUP-08 · LOW · `purchase_bindings` race yields a spurious denial

**Files:** `verify-receipt/index.ts:64-92` · `202607050001_purchase_bindings.sql:2`

```sql
token_hash text primary key,
```

`bindPurchaseToken` reads then inserts without a transaction, so concurrent requests for one token can both pass the lookup. **The PK on `token_hash` prevents the dangerous outcome** — the second insert fails, `inserted.ok` is false, `bound` is false, and `valid: valid && bound` denies entitlement rather than creating a duplicate binding. The anti-sharing guarantee holds.

**Impact:** The losing request returns `{valid: false, error: "purchase binding failed"}` to a legitimate purchaser. Retrying succeeds, because the lookup then finds their own binding. Transient and self-healing.

**Fix (optional):** Collapse to one statement — `POST` with `Prefer: resolution=ignore-duplicates`, then re-read and compare `user_id`.

---

## SUP-09 · LOW · Empty migration committed

**File:** `supabase/migrations/20260711160649_new-migration.sql` — **0 lines**

A zero-byte migration with the CLI's placeholder name. Harmless to apply, but it occupies a version slot in `supabase_migrations.schema_migrations` and signals an abandoned change.

**Fix:** Delete it if it has not been applied to production. If it has, leave it — removing an applied migration causes history drift.

---

## SUP-10 · LOW · Two incompatible migration naming schemes

```
202607050001_purchase_bindings.sql            12-digit  YYYYMMDDNNNN
202607110001_profiles.sql                     12-digit
202607110002_data_policies.sql                12-digit
20260711160649_new-migration.sql              14-digit  YYYYMMDDHHMMSS  ← Supabase standard
20260712143000_resilient_handle_new_user.sql  14-digit
```

Migrations apply in lexicographic order. The current five happen to sort correctly, but the schemes are not comparable in general: a future 12-digit file dated the same day as a 14-digit one sorts **before** it regardless of actual authoring time (`202607120001` < `20260712143000`).

**Why this matters here:** `20260712143000_resilient_handle_new_user.sql` exists specifically to *replace* the `handle_new_user` defined in `202607110001_profiles.sql`. Ordering is load-bearing. A new 12-digit migration touching that function could silently re-apply the older definition.

**Fix:** Use the CLI's 14-digit format exclusively (`supabase migration new <name>`).

---

## SUP-11 · LOW · `supabase/.temp/` is committed to git

**Evidence:** `git ls-files supabase/` returns all nine `.temp/` files, including:

- `linked-project.json` — project ref, name, organization ID and slug
- `project-ref` — the project reference
- `pooler-url` — `postgresql://<user>@aws-1-us-west-2.pooler.supabase.com:5432/postgres`

**Verified: `pooler-url` contains no password.** A structural test for `postgresql://USER:PASSWORD@HOST` did not match — the URL carries user and host only. This is a connection template, not a credential.

**Impact:** Low. The project ref appears in the client-side Supabase URL anyway and is not secret. What is disclosed is the organization ID/slug and the exact region — mild reconnaissance value, and the files are CLI-local state that has no business being versioned.

**Fix:** Add `supabase/.temp/` to `.gitignore` and `git rm -r --cached supabase/.temp`.

---

## SUP-12 · LOW · Dead no-op statement in a migration

**File:** `supabase/migrations/202607110002_data_policies.sql:19-21`

```sql
update public.user_daily_metrics
set user_id = auth.uid()
where user_id is null and auth.uid() is not null;
```

Migrations run as the `postgres`/service role, where `auth.uid()` is **NULL**. The `and auth.uid() is not null` guard therefore makes this a guaranteed no-op — it never backfills anything.

**Impact:** No damage, but it creates the false impression that NULL `user_id` rows were backfilled. That assumption is what makes the `user_id is null` branch in SUP-02's UPDATE policy look harmless when it is not.

**Fix:** Delete the statement, and backfill NULL owners deliberately out-of-band before applying the SUP-02 `not null` constraint.

---

## SUP-13 · INFO · No DELETE path on `user_daily_metrics`

**File:** `202607110002_data_policies.sql:45`

```sql
grant select, insert, update on table public.user_daily_metrics to authenticated;
```

No DELETE grant and no DELETE policy. Users cannot delete their own metrics. `profiles` has the same gap, though it is mitigated by `on delete cascade` from `auth.users`.

`user_daily_metrics.user_id` also has `on delete cascade` (line 4), so deleting the auth user does clear the rows — meaning full-account erasure works. What is missing is *selective* erasure of activity history without deleting the account.

**Fix:** If the privacy policy offers granular data deletion, add a DELETE grant and an `auth.uid() = user_id` policy. Note `.env` declares a `CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT` — confirm that function exists and is deployed, since it is referenced but absent from `supabase/functions/`.

---

## B. Edge function assessment

### `ai-proxy` — well built, three gaps

| Control | Status |
|---|---|
| JWT verification before upstream call | ✅ `index.ts:22-31, 77-83` |
| Provider key server-side only | ✅ `Deno.env.get("ANTHROPIC_API_KEY")`, line 44 |
| Prompt size cap | ✅ 8,000 chars / 8 history messages, line 106 |
| History window | ✅ `slice(-6)`, line 120 |
| `max_tokens` clamped server-side | ✅ `Math.max(128, Math.min(MAX_TOKENS, …))`, line 129 |
| Model not client-overridable | ✅ line 128 |
| Error messages generic | ✅ "Upstream AI error" — no upstream detail leaked |
| Response body cancelled on error | ✅ `await res.body?.cancel()`, line 145 |
| CORS restrictive | ✅ ACAO omitted for unlisted origins, line 16 |
| Rate limiting effective | ❌ SUP-03 |
| System prompt server-controlled | ❌ SUP-04 |
| Upstream timeout | ❌ SUP-06 |

**Response parsing** (`line 154`): `data.content?.[0]?.text ?? ""` — optional chaining means a malformed response yields an empty string rather than a crash. Acceptable, though it makes an upstream shape change indistinguishable from an empty answer.

**CORS note:** native mobile clients send no `Origin` header, so `ALLOWED_ORIGINS` gates browser callers only. Correct for this app; the JWT check is the real control.

### `verify-receipt` — the strongest component in the system

| Control | Status |
|---|---|
| JWT verification | ✅ lines 29-38, 176-182 |
| Real Google Play Developer API call | ✅ `androidpublisher/v3`, `subscriptionsv2` for subs — line 209-215 |
| Service-account JWT (RS256) | ✅ correct PKCS#8 import + `crypto.subtle.sign`, lines 113-164 |
| Product ID allowlist | ✅ `ALLOWED_PRODUCT_IDS`, lines 8-11, enforced line 192 |
| Purchase token bound to a user | ✅ SHA-256 hash + `purchase_bindings`, lines 49-92 |
| Anti-sharing enforced | ✅ `existing[0]?.user_id === userId`, line 76 |
| Binding failure denies entitlement | ✅ `valid: valid && bound`, lines 244, 261 |
| Service-role key server-side only | ✅ never returned to the client |
| Grace period handled | ✅ `SUBSCRIPTION_STATE_IN_GRACE_PERIOD`, line 239 |
| URL components encoded | ✅ `encodeURIComponent` on all three, lines 210-212 |
| Rate limiting effective | ❌ SUP-03 |
| Upstream timeout | ❌ SUP-06 |

This is **not** a stub — a common failure mode in receipt verifiers is returning `true` unconditionally, which silently gives away paid features. This implementation does the real work.

---

## C. `config.toml` and project settings

`supabase/config.toml` holds local-development defaults. Production auth settings (signup enabled, email confirmation, JWT expiry, refresh-token rotation) live in the hosted dashboard and **cannot be audited from the repository**.

**Verify manually in the dashboard — these directly affect SUP-01's blast radius:**

1. **Is public signup enabled?** If yes, SUP-01 is exploitable by anyone on the internet. If invite-only, exposure is limited to existing users — still a breach, smaller radius.
2. **Is email confirmation required?** Without it, an attacker self-serves a JWT with a throwaway address.
3. **Refresh token rotation** — should be on.
4. **JWT expiry** — default 3600s is reasonable.
5. **`verify_jwt`** on both deployed functions — should be enabled at the platform level as defence in depth, in addition to the in-code check.

---

## Priority

1. **SUP-01** — fix immediately and independently of any release. One-line policy change. Then assess whether exposure occurred (check PostgREST logs for broad `user_daily_metrics` selects) and whether disclosure obligations are triggered.
2. **SUP-02** — same table; fix in the same session.
3. **SUP-04, SUP-03** — cost-abuse pair on the AI proxy.
4. **SUP-05, SUP-06** — reliability.
5. Remainder — housekeeping.
