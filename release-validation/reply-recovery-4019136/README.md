# Provider-free reply-recovery evidence probe

This support probe exercises release source 401913600150334749118e6907b0be2c5f062839 (tree f8e9fa7c6e4a332e1874e8a227046f7df9f327db). It is test tooling outside that release source; it does not change, rebuild, sign or publish the Android candidate.

## Scope and interpretation

The actual ai-proxy handler is captured in-process without opening an Edge server. Auth, reservations, settlement RPCs, principal joins, wallet/ledger records, TTL and deletion are real calls to an exclusively disposable localhost Supabase. Exactly two fresh requests receive in-memory synthetic provider responses; completed retries must make no additional provider attempts. Deno and the transport wrapper restrict outbound traffic to 127.0.0.1:54321. No paid provider, production service, real account or payment is used.

The intended database checks cover:

- The named TTL overload resolving through PostgREST, completed payload/expiry readback, and exactly one debit per original request.
- A successful settlement whose response is deliberately discarded after commit; the actual handler must reconcile it.
- Two concurrent completed retries returning the same cached answer without another debit or provider attempt.
- Cross-account row isolation and account/request-bound quotes; malformed payload and missing expiry refused.
- Expired reply refusal followed by the real purge RPC. Purge clears payload/expiry; owner deletion separately clears provider-request metadata.
- Deleting the two owned synthetic accounts, verifying their absence and content scrubbing, while retaining the schema's non-content accounting tombstones.

The probe does not claim fault-tested transactional rollback, real-provider availability/quality, Edge gateway deployment, production parity/cron cadence, installed-device acceptance or release approval. Retired/mismatched-principal branches retain existing source unit-test coverage; this probe tests the real active join and deleted owner. A localhost URL alone cannot establish database identity: the operator must establish a fresh, dedicated, exclusive local instance with no hosted proxy.

## Local preparation verification

Use existing Deno 2.9.4; no package install is needed. These commands use no backend and no credentials:

~~~bash
deno fmt --no-config --check guards.ts reply_recovery_probe.ts probe_guard_test.ts
deno check --no-config --no-lock --no-remote --no-npm reply_recovery_probe.ts probe_guard_test.ts
deno test --no-config --no-lock --no-remote --no-npm --deny-net --deny-env --deny-run --deny-write --no-prompt probe_guard_test.ts
deno run --no-config --no-lock --no-remote --no-npm --deny-net --deny-env --deny-run --deny-write --no-prompt \
  --allow-read="$SOURCE_ROOT,$PWD" reply_recovery_probe.ts --verify-source --source-root "$SOURCE_ROOT"
~~~

SOURCE_ROOT is a checkout of the fixed release tree. The hash-pinned manifest checks ten handler/dependency files and all 57 reviewed migrations, allowing only checkout CRLF-to-LF normalization. This verifies source files, not the running database's migration catalog.

## Execute only in a fresh disposable backend

The proposed hosted packet creates this isolated backend on an ephemeral Ubuntu runner. It uses the repository's pinned Supabase CLI 2.116.0 and copies the exact source's tracked supabase directory into a separate temporary project. The source checkout remains unchanged.

For an already provisioned local environment, an operator must first verify its dedicated identity and empty application data. Pass local keys only through LOCAL_SUPABASE_ANON_KEY and LOCAL_SUPABASE_SERVICE_KEY; never save keys in an attestation or report. Set LOCAL_SUPABASE_URL to exactly http://127.0.0.1:54321 and AXIOMARA_DISPOSABLE_DB_GATE=true.

The attestation JSON must contain schemaVersion:1, the exact sourceSha/sourceTree above, apiUrl, disposable:true, exclusive:true, noHostedProxy:true, freshMigrationReplay:true, a localProjectId, and a createdAt UTC timestamp less than one hour old. Those are operator statements, not facts manufactured by the probe. The workflow creates them only after starting its own fresh project.

~~~bash
deno run --no-config --no-lock --no-remote --no-npm --no-prompt --deny-run --deny-ffi \
  --allow-env=AXIOMARA_DISPOSABLE_DB_GATE,LOCAL_SUPABASE_URL,LOCAL_SUPABASE_ANON_KEY,LOCAL_SUPABASE_SERVICE_KEY \
  --allow-net=127.0.0.1:54321 --deny-net=api.anthropic.com:443 \
  --allow-read="$SOURCE_ROOT,$PWD,$ATTESTATION" --allow-write="$NEW_OUTPUT" \
  reply_recovery_probe.ts --execute --source-root "$SOURCE_ROOT" \
  --attestation "$ATTESTATION" --output "$NEW_OUTPUT"
~~~

NEW_OUTPUT must not already exist. The database must initially contain no Auth users or rows in the four billing/usage tables checked by the probe. Do not run this after other fixture suites in the same project: retained accounting tombstones deliberately make a reuse attempt fail. The global expiry purge is permitted only after another complete usage-row inventory confirms every row belongs to this probe. A concurrent cron purge that prevents proving this call's effect is reported as inconclusive failure, not silently accepted.

Output is started.json and, on completed execution, result.json. Missing result.json means incomplete execution. PASS requires all behavioral assertions and verified cleanup; no failure is converted to a pass. Errors are categorized without raw responses, keys, passwords or synthetic account identifiers.

## Hosted packet, pending approval

The prepared packet adds only one workflow and six support files on a temporary test-only branch. The workflow runs on a same-repository pull request to main from codex/axiomara-reply-recovery-evidence-4019136. It has contents:read only, no repository secrets, no environment, no deployment, no scheduled trigger and no manual-dispatch trigger.

A new workflow_dispatch-only file is not the reliable first-run route because GitHub documents its default-branch requirement. The ordinary pull_request event runs from a PR merge reference; the packet explicitly checks out the overlay head and the release commit separately and records both identities. No merge is needed. See [GitHub event documentation](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#pull_request) and [manual dispatch requirements](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_dispatch).

Opening the temporary PR can also trigger existing repository PR checks. This does not authorize merging it, dispatching release workflows, altering hosted Supabase or changing Play tracks. The packet refuses a different main base; refresh/review it if main has moved from the fixed release SHA.

## Current evidence boundary

Preparation type checks, 61 guard tests, 51 existing handler tests and the 67-file source-binding check passed locally. The real database probe and proposed hosted workflow have not been executed. A successful local preparation receipt is not a database PASS.

The [Supabase local-development guide](https://supabase.com/docs/guides/local-development/cli/getting-started) describes the Docker-backed stack. Only the proposed workflow's newly created per-run project is eligible for its stop --no-backup cleanup; never use that command against an existing personal database.
