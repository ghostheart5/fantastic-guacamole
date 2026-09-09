// Single-use, explicitly dispatched repair rollout. No user rows, wallet calls,
// provider requests, reconciliation, publication or arbitrary SQL are accepted.
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { cpSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, realpathSync,
  rmSync, writeFileSync } from 'node:fs';
import { join, relative, isAbsolute, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { CREDIT_AUTHORITY_QUERY, CREDIT_AUTHORITY_FUNCTIONS, expectedCohortFingerprint,
  verifyBackendRepairGate, verifyCreditAuthorityGrants } from './verify_backend_repair_gate.mjs';

export const PROJECT = 'qpwhuckyirnqtmvhpede';
export const REPOSITORY = 'ghostheart5/fantastic-guacamole';
export const REF = 'refs/heads/fix/app-only-readiness-priority2-20260902';
export const MIGRATION = '20260909065846_revoke_obsolete_client_credit_debit.sql';
export const BASELINE_SHA256 = 'e62bfac2470f3ab03be75709d0b115618b7fbec1db2b43d84ed2db3277339000';
export const MIGRATION_SHA256 = '2f6809204df8578ee4251e74b01193e2c6954f12f21d7478aa4b1addd206422e';
export const FUNCTIONS = [['ai-proxy', true], ['planner-explanation', true], ['account-delete', false]];
const COHORT = 'CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS';
const sha256 = (value) => createHash('sha256').update(value).digest('hex');
export class RolloutError extends Error {}
function require(condition, message) { if (!condition) throw new RolloutError(message); }

export function validateSource(env, checkout, toolingCheckout, ci) {
  require(env.GITHUB_ACTIONS === 'true' && env.GITHUB_EVENT_NAME === 'workflow_dispatch' &&
    env.GITHUB_REPOSITORY === REPOSITORY && env.GITHUB_REF === REF &&
    env.BACKEND_REPAIR_OPERATION === 'apply-reviewed-repairs', 'Repair dispatch context is not authorized');
  const source = env.BACKEND_REPAIR_SOURCE_SHA;
  require(/^[a-f0-9]{40}$/.test(source ?? '') && source === checkout,
    'Selected repair source and app checkout must match');
  require(/^[a-f0-9]{40}$/.test(env.GITHUB_SHA ?? '') && toolingCheckout === env.GITHUB_SHA,
    'Repair tooling checkout must match the dispatched workflow SHA');
  require(/^[1-9][0-9]*$/.test(env.BACKEND_REPAIR_CI_RUN ?? ''), 'Exact-source CI run is required');
  if (ci !== undefined) {
    require(ci && String(ci.id) === env.BACKEND_REPAIR_CI_RUN && ci.head_sha === source &&
      ci.repository?.full_name === REPOSITORY && ci.path === '.github/workflows/ci.yml' &&
      ci.event === 'workflow_dispatch' && ci.status === 'completed' && ci.conclusion === 'success',
    'Successful manual CI for the exact repair source is required');
  }
}

export function validateEnvironment(env) {
  require(env.SUPABASE_PROJECT_REF === PROJECT &&
    env.CHRONOSPARK_SUPABASE_URL === `https://${PROJECT}.supabase.co`, 'Repair project identity mismatch');
  for (const name of ['GH_TOKEN', 'SUPABASE_ACCESS_TOKEN', 'SUPABASE_DB_PASSWORD', 'SUPABASE_SECRET_KEY']) {
    require(typeof env[name] === 'string' && env[name].trim().length > 0, `Missing ${name}`);
  }
  expectedCohortFingerprint(env[COHORT]);
}

export function validateMigrationInventory(files, remote, migrationText) {
  require(Array.isArray(files) && files.length === 50 && files.includes(MIGRATION) &&
    new Set(files).size === files.length && files.every((name) => /^\d{12,14}_[a-z0-9_-]+\.sql$/.test(name)),
  'Local migration inventory differs from the reviewed set');
  const baseline = files.filter((name) => name !== MIGRATION).map((name) => name.slice(0, -4)).sort();
  require(sha256(baseline.join('\n')) === BASELINE_SHA256, 'Local migration baseline differs from review');
  require(Array.isArray(remote) && remote.length === 49 && remote.every((item) =>
    typeof item?.version === 'string' && typeof item?.name === 'string'), 'Remote migration count or shape drifted');
  const deployed = remote.map((item) => `${item.version}_${item.name}`).sort();
  require(sha256(deployed.join('\n')) === BASELINE_SHA256, 'Remote migration history drifted');
  require(typeof migrationText === 'string' && sha256(migrationText.replaceAll('\r\n', '\n')) === MIGRATION_SHA256,
    'Reviewed credit revocation migration content changed');
}

export function validateDryRun(output) {
  const names = [...new Set(output.match(/\b\d{12,14}_[a-z0-9_-]+\.sql\b/g) ?? [])];
  require(names.length === 1 && names[0] === MIGRATION, 'CLI dry run did not select only the reviewed migration');
}

export function validatePriorGrants(rows) {
  require(Array.isArray(rows), 'Prior credit authority grants are invalid');
  const oldClient = rows.filter((row) => row?.signature === CREDIT_AUTHORITY_FUNCTIONS[0] &&
    row.role_name === 'authenticated');
  require(oldClient.length === 1 && oldClient[0].present === true && oldClient[0].can_execute === true,
    'Prior obsolete credit grant drifted');
  verifyCreditAuthorityGrants(rows.map((row) => row === oldClient[0] ? { ...row, can_execute: false } : row));
}

function metadata(functions) {
  require(Array.isArray(functions), 'Function metadata is invalid');
  return FUNCTIONS.map(([slug]) => {
    const matches = functions.filter((item) => item?.slug === slug);
    const value = matches[0];
    require(matches.length === 1 && value.status === 'ACTIVE' && Number.isSafeInteger(value.version) &&
      value.version > 0 && typeof value.verify_jwt === 'boolean' && /^[a-f0-9]{64}$/.test(value.ezbr_sha256 ?? ''),
    'Function rollback metadata is incomplete');
    return { slug, version: value.version, verifyJwt: value.verify_jwt, bundleSha256: value.ezbr_sha256 };
  });
}

// Child output stays in memory. A CLI/network failure may contain credentials;
// do not forward exception text, stdout, stderr, headers or response bodies.
export function command(args, cwd, env, timeout = 120000) {
  const result = spawnSync(args[0], args.slice(1), {
    cwd, env, encoding: 'utf8', timeout, maxBuffer: 4 * 1024 * 1024, windowsHide: true,
  });
  require(!result.error && result.status === 0, 'Repair subprocess failed or timed out');
  return `${result.stdout ?? ''}${result.stderr ?? ''}`;
}

export async function rollout(env = process.env, options = {}) {
  const request = options.request ?? fetch;
  const run = options.command ?? command;
  const root = options.root ?? process.cwd();
  const toolingRoot = options.toolingRoot;
  const preflight = options.preflight ?? verifyBackendRepairGate;
  let scratch;
  let evidenceDirectory;
  const receipt = { schemaVersion: 1, completedStages: [], verified: false };
  let stage = 'source-and-environment';
  const writeReceipt = () => {
    if (evidenceDirectory) writeFileSync(join(evidenceDirectory, 'rollout.json'), `${JSON.stringify(receipt, null, 2)}\n`, { mode: 0o600 });
  };
  try {
    require(typeof toolingRoot === 'string' && realpathSync(toolingRoot) !== realpathSync(root),
      'Separate immutable app and tooling checkouts are required');
    const checkout = run(['git', 'rev-parse', 'HEAD'], root, env).trim();
    const toolingCheckout = run(['git', 'rev-parse', 'HEAD'], toolingRoot, env).trim();
    validateSource(env, checkout, toolingCheckout);
    require(run(['git', 'status', '--porcelain', '--untracked-files=no'], root, env).trim() === '',
      'Tracked repair checkout is dirty');
    require(run(['git', 'status', '--porcelain', '--untracked-files=no'], toolingRoot, env).trim() === '',
      'Tracked repair tooling checkout is dirty');
    validateEnvironment(env);
    const http = async (url, init = {}) => {
      const response = await request(url, { ...init, redirect: 'error', signal: AbortSignal.timeout(30000) });
      require(response.ok, 'Repair API request failed');
      return response;
    };
    const github = await http(`https://api.github.com/repos/${REPOSITORY}/actions/runs/${env.BACKEND_REPAIR_CI_RUN}`, {
      headers: { Authorization: `Bearer ${env.GH_TOKEN}`, Accept: 'application/vnd.github+json' },
    });
    validateSource(env, checkout, toolingCheckout, await github.json());
    receipt.sourceSha = checkout;
    receipt.toolingSha = toolingCheckout;
    receipt.ciRun = env.BACKEND_REPAIR_CI_RUN;
    receipt.projectRef = PROJECT;
    const tempRoot = realpathSync(env.RUNNER_TEMP);
    evidenceDirectory = join(tempRoot, 'chronospark-backend-repair-evidence');
    mkdirSync(evidenceDirectory, { recursive: true, mode: 0o700 });
    scratch = mkdtempSync(join(tempRoot, 'chronospark-backend-repair-private-'));
    const headers = { Authorization: `Bearer ${env.SUPABASE_ACCESS_TOKEN}`,
      'Content-Type': 'application/json', 'User-Agent': 'ChronoSpark reviewed repair rollout' };
    const apiRoot = `https://api.supabase.com/v1/projects/${PROJECT}`;
    const api = async (path) => (await http(`${apiRoot}${path}`, { headers })).json();
    stage = 'read-only-baseline';
    const project = await api('');
    require((project.id ?? project.ref) === PROJECT && project.status === 'ACTIVE_HEALTHY', 'Live repair project is not ready');
    const files = readdirSync(join(root, 'supabase', 'migrations')).filter((name) => name.endsWith('.sql'));
    const migrationText = readFileSync(join(root, 'supabase', 'migrations', MIGRATION), 'utf8');
    validateMigrationInventory(files, await api('/database/migrations'), migrationText);
    validatePriorGrants(await (await http(`${apiRoot}/database/query/read-only`, {
      method: 'POST', headers, body: JSON.stringify({ query: CREDIT_AUTHORITY_QUERY }),
    })).json());
    receipt.priorCreditAuthorityMatched = true;
    receipt.before = metadata(await api('/functions'));
    for (const entry of receipt.before) {
      const result = await http(`${apiRoot}/functions/${entry.slug}/body`, { headers });
      const body = Buffer.from(await result.arrayBuffer());
      require(body.length > 0 && body.length < 16 * 1024 * 1024, 'Rollback body is empty or exceeds the evidence limit');
      // Preserve hashes and version/config only; hosted source bodies are never
      // placed in logs/artifacts because legacy source may contain private data.
      entry.downloadSha256 = sha256(body);
    }
    receipt.migration = { file: MIGRATION, sha256: MIGRATION_SHA256, remoteBeforeCount: 49 };
    writeReceipt();
    const cli = (args, timeout) => run(['supabase', ...args, '--workdir', scratch], scratch, env, timeout);
    require(/^2\.116\.0(?:\s|$)/.test(run(['supabase', '--version'], scratch, env).trim()), 'Reviewed Supabase CLI version is required');
    mkdirSync(join(scratch, 'supabase'), { mode: 0o700 });
    // This minimal configuration excludes seeds, vault settings and all
    // unrelated functions. Explicit deploy arguments below select only three.
    writeFileSync(join(scratch, 'supabase', 'config.toml'), FUNCTIONS.map(([slug, jwt]) =>
      `[functions.${slug}]\nverify_jwt = ${jwt}\n`).join('\n'), { mode: 0o600 });
    cpSync(join(root, 'supabase', 'migrations'), join(scratch, 'supabase', 'migrations'), { recursive: true });
    cpSync(join(root, 'supabase', 'functions'), join(scratch, 'supabase', 'functions'), { recursive: true });
    cli(['link', '--project-ref', PROJECT, '--yes']);
    validateDryRun(cli(['db', 'push', '--linked', '--dry-run', '--skip-vault', '--yes']));
    // Fence late drift after snapshot/link/dry-run and before the first write.
    validateMigrationInventory(files, await api('/database/migrations'), migrationText);
    require(JSON.stringify(metadata(await api('/functions'))) ===
      JSON.stringify(receipt.before.map(({ downloadSha256: _download, ...entry }) => entry)),
    'Function metadata drifted after rollback snapshot');
    receipt.completedStages.push('baseline-and-dry-run');
    writeReceipt();
    stage = 'set-private-cohort';
    const configured = await http(`${apiRoot}/secrets`, { method: 'POST', headers,
      body: JSON.stringify([{ name: COHORT, value: env[COHORT] }]) });
    await configured.body?.cancel();
    receipt.completedStages.push('private-cohort-set');
    writeReceipt();
    stage = 'apply-reviewed-migration';
    validateMigrationInventory(files, await api('/database/migrations'), migrationText);
    cli(['db', 'push', '--linked', '--skip-vault', '--yes'], 180000);
    const migrated = await api('/database/migrations');
    require(Array.isArray(migrated) && migrated.length === 50 &&
      migrated.filter((item) => item?.version === MIGRATION.split('_')[0] &&
        item.name === MIGRATION.slice(15, -4)).length === 1, 'Applied migration readback did not match');
    validateMigrationInventory(files, migrated.filter((item) => item.version !== MIGRATION.split('_')[0]), migrationText);
    receipt.completedStages.push('reviewed-migration-applied');
    writeReceipt();
    for (const [slug, jwt] of FUNCTIONS) {
      stage = `deploy-${slug}`;
      const args = ['functions', 'deploy', slug, '--project-ref', PROJECT, '--use-api'];
      if (!jwt) args.push('--no-verify-jwt');
      cli(args, 180000);
      receipt.completedStages.push(`deployed-${slug}`);
      writeReceipt();
    }
    stage = 'read-only-postflight';
    receipt.after = metadata(await api('/functions'));
    for (const [slug, jwt] of FUNCTIONS) {
      const before = receipt.before.find((item) => item.slug === slug);
      const after = receipt.after.find((item) => item.slug === slug);
      require(after.verifyJwt === jwt && after.version > before.version && after.bundleSha256 !== before.bundleSha256,
        'Deployed function version, hash or gateway did not advance as reviewed');
    }
    receipt.backendRepairGate = await preflight(env, request);
    receipt.completedStages.push('read-only-postflight');
    receipt.verified = true;
    writeReceipt();
    return receipt;
  } catch {
    receipt.failedStage = stage;
    writeReceipt();
    // Stage names are literals controlled by this module. Do not relay the
    // original error, even if a dependency labels it as a validation error.
    throw new RolloutError(`Reviewed backend repair failed during ${stage}; inspect sanitized evidence`);
  } finally {
    if (scratch) {
      const target = realpathSync(scratch);
      const parent = realpathSync(env.RUNNER_TEMP);
      const child = relative(parent, target);
      require(child.startsWith('chronospark-backend-repair-private-') && !child.includes('..') && !isAbsolute(child),
        'Private repair cleanup target is outside its owned directory');
      rmSync(target, { recursive: true, force: true });
    }
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    require(process.argv.length === 4, 'Explicit app and tooling checkout paths are required');
    await rollout(process.env, { root: resolve(process.argv[2]), toolingRoot: resolve(process.argv[3]) });
    console.log('Reviewed backend repairs passed the deployed read-only gate.');
  } catch (error) {
    console.error(error instanceof RolloutError ? error.message : 'Reviewed backend repair failed');
    process.exitCode = 1;
  }
}
