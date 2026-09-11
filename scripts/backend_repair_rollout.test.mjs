import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, copyFileSync, readdirSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PROJECT, REPOSITORY, REF, MIGRATION, FUNCTIONS, command, rollout,
  validateSource, validateEnvironment, validateMigrationInventory, validateDryRun, validatePriorGrants } from './backend_repair_rollout.mjs';
import { CREDIT_AUTHORITY_FUNCTIONS, CREDIT_AUTHORITY_QUERY } from './verify_backend_repair_gate.mjs';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
// This one-use rollout is permanently fenced to its September 9 inventory.
// Later app migrations must not silently widen that original deployment scope.
const currentFiles = readdirSync(join(root, 'supabase/migrations')).filter((name) => name.endsWith('.sql'));
const files = currentFiles.filter((name) => name <= MIGRATION);
const migration = readFileSync(join(root, 'supabase/migrations', MIGRATION), 'utf8');
const remote = files.filter((name) => name !== MIGRATION).map((name) => {
  const split = name.indexOf('_');
  return { version: name.slice(0, split), name: name.slice(split + 1, -4) };
});
const source = 'a'.repeat(40);
const toolingSource = 'e'.repeat(40);
const privateValue = 'synthetic-private-value-not-for-output';
const env = {
  GITHUB_ACTIONS: 'true', GITHUB_EVENT_NAME: 'workflow_dispatch', GITHUB_REPOSITORY: REPOSITORY,
  GITHUB_REF: REF, GITHUB_SHA: toolingSource, BACKEND_REPAIR_OPERATION: 'apply-reviewed-repairs',
  BACKEND_REPAIR_SOURCE_SHA: source, BACKEND_REPAIR_CI_RUN: '42',
  SUPABASE_PROJECT_REF: PROJECT, CHRONOSPARK_SUPABASE_URL: `https://${PROJECT}.supabase.co`,
  GH_TOKEN: privateValue, SUPABASE_ACCESS_TOKEN: privateValue,
  SUPABASE_SECRET_KEY: privateValue, SUPABASE_DB_PASSWORD: privateValue,
  CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS: 'b'.repeat(64),
};
const ci = { id: 42, head_sha: source, repository: { full_name: REPOSITORY },
  path: '.github/workflows/ci.yml', event: 'workflow_dispatch', status: 'completed', conclusion: 'success' };
const priorGrants = CREDIT_AUTHORITY_FUNCTIONS.flatMap((signature, index) =>
  ['anon', 'authenticated', 'service_role'].map((role_name) => ({ signature, role_name, present: true,
    can_execute: index === 0 ? role_name === 'authenticated' : role_name === 'service_role' })));

test('live grant baseline requires the obsolete authenticated grant and intact service-only canonical authority', () => {
  validatePriorGrants(priorGrants);
  for (let index = 0; index < priorGrants.length; index += 1) {
    const changed = priorGrants.map((row, i) => i === index ? { ...row, can_execute: !row.can_execute } : row);
    assert.throws(() => validatePriorGrants(changed));
  }
});

test('app and tooling checkouts independently match their immutable source and workflow identities', () => {
  validateSource(env, source, toolingSource, ci);
  assert.notEqual(source, toolingSource);
  for (const [name, value] of [
    ['GITHUB_ACTIONS', 'false'], ['GITHUB_EVENT_NAME', 'schedule'], ['GITHUB_REPOSITORY', 'wrong/repo'],
    ['GITHUB_REF', 'refs/heads/main'], ['GITHUB_SHA', 'c'.repeat(40)],
    ['BACKEND_REPAIR_OPERATION', 'reconcile'], ['BACKEND_REPAIR_SOURCE_SHA', 'main'], ['BACKEND_REPAIR_CI_RUN', '../42'],
  ]) assert.throws(() => validateSource({ ...env, [name]: value }, source, toolingSource, ci));
  assert.throws(() => validateSource(env, 'c'.repeat(40), toolingSource, ci));
  assert.throws(() => validateSource(env, source, source, ci));
  assert.throws(() => validateSource({ ...env, GITHUB_REF: 'refs/heads/fix/aab-prebuild-cleanup-20260905' }, source, toolingSource, ci));
  for (const [name, value] of [
    ['id', 43], ['head_sha', 'c'.repeat(40)], ['repository', { full_name: 'wrong/repo' }],
    ['path', '.github/workflows/android-release.yml'], ['event', 'push'], ['status', 'in_progress'], ['conclusion', 'failure'],
  ]) assert.throws(() => validateSource(env, source, toolingSource, { ...ci, [name]: value }));
});

test('wrong project, URL, missing credentials and invalid cohort fail before writes', () => {
  validateEnvironment(env);
  for (const [name, value] of [
    ['SUPABASE_PROJECT_REF', 'wrong-project'], ['CHRONOSPARK_SUPABASE_URL', 'https://elsewhere.invalid'],
    ...['GH_TOKEN', 'SUPABASE_ACCESS_TOKEN', 'SUPABASE_SECRET_KEY', 'SUPABASE_DB_PASSWORD'].map((name) => [name, '']),
    ['CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS', privateValue],
    ['CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS', `${'b'.repeat(64)},${'b'.repeat(64)}`],
  ]) {
    assert.throws(() => validateEnvironment({ ...env, [name]: value }), (error) => !error.message.includes(privateValue));
  }
});

test('exact 49 deployed migrations and single unmodified pending migration are required', () => {
  validateMigrationInventory(files, remote, migration);
  for (const history of [remote.slice(1), [...remote, { version: '20990101000000', name: 'unexpected' }],
    [...remote.slice(0, -1), remote[0]], [...remote.slice(0, -1), { ...remote.at(-1), name: 'changed' }],
    [...remote, { version: '20260909065846', name: 'revoke_obsolete_client_credit_debit' }]]) {
    assert.throws(() => validateMigrationInventory(files, history, migration));
  }
  assert.throws(() => validateMigrationInventory([...files, '20990101000000_unreviewed.sql'], remote, migration));
  if (currentFiles.length > files.length) {
    assert.throws(() => validateMigrationInventory(currentFiles, remote, migration));
  }
  assert.throws(() => validateMigrationInventory(files, remote, `${migration}\ngrant all to public;`));
  validateMigrationInventory(files, remote, migration.replaceAll('\n', '\r\n'));
  validateDryRun(`Would push these migrations:\n - ${MIGRATION}\n`);
  for (const output of ['', 'Remote database is up to date', `${MIGRATION}\n20990101000000_unreviewed.sql`]) {
    assert.throws(() => validateDryRun(output));
  }
});

function fixture(overrides = {}) {
  const temp = mkdtempSync(join(tmpdir(), 'chronospark-rollout-contract-'));
  const appRoot = join(temp, 'reviewed-app');
  mkdirSync(join(appRoot, 'supabase/migrations'), { recursive: true });
  mkdirSync(join(appRoot, 'supabase/functions'), { recursive: true });
  for (const name of files) copyFileSync(join(root, 'supabase/migrations', name), join(appRoot, 'supabase/migrations', name));
  const state = { migrated: false, deployed: new Set(), calls: [], historyReads: 0, ...overrides };
  const setup = { env: { ...env, RUNNER_TEMP: temp, ...overrides.env }, state, temp };
  const functions = () => FUNCTIONS.map(([slug, jwt]) => ({ slug, status: 'ACTIVE',
    version: state.deployed.has(slug) ? 20 : 19,
    verify_jwt: state.deployed.has(slug) ? jwt : true,
    ezbr_sha256: (state.deployed.has(slug) ? 'd' : 'c').repeat(64),
  }));
  const request = async (url, init) => {
    state.calls.push({ kind: 'http', url, method: init.method ?? 'GET' });
    assert.equal(init.redirect, 'error');
    assert.ok(init.signal instanceof AbortSignal);
    if (state.networkError) throw new Error(privateValue);
    if (url.startsWith('https://api.github.com/')) return Response.json(state.ci ?? ci);
    assert.ok(url.startsWith(`https://api.supabase.com/v1/projects/${PROJECT}`));
    const path = url.slice(`https://api.supabase.com/v1/projects/${PROJECT}`.length);
    if (path === '') return Response.json({ id: PROJECT, status: 'ACTIVE_HEALTHY' });
    if (path === '/database/migrations') {
      state.historyReads += 1;
      if (state.historyReads === state.driftOnRead) return Response.json(remote.slice(1));
      return Response.json(state.migrated ? [...remote,
        { version: '20260909065846', name: 'revoke_obsolete_client_credit_debit' }] : remote);
    }
    if (path === '/functions') return Response.json(functions());
    if (path === '/database/query/read-only') {
      assert.equal(init.method, 'POST');
      assert.deepEqual(JSON.parse(init.body), { query: CREDIT_AUTHORITY_QUERY });
      return Response.json(state.grants ?? priorGrants);
    }
    if (path.endsWith('/body')) return new Response('synthetic-function-body');
    assert.equal(path, '/secrets');
    assert.equal(init.method, 'POST');
    assert.deepEqual(JSON.parse(init.body), [{ name: 'CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS', value: env.CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS }]);
    if (state.secretFailure) return new Response(privateValue, { status: 403 });
    return Response.json({}, { status: 201 });
  };
  const run = (args, cwd, passedEnv) => {
    state.calls.push({ kind: 'command', args });
    assert.equal(passedEnv, setup.env);
    assert.equal(args.some((item) => item.includes(privateValue)), false);
    if (args[0] === 'git') {
      if (args[1] === 'rev-parse') return cwd === appRoot ? source : toolingSource;
      return cwd === appRoot ? (state.dirtyApp ?? '') : (state.dirtyTooling ?? '');
    }
    assert.equal(args[0], 'supabase');
    if (args[1] === '--version') return '2.116.0\n';
    assert.ok(cwd.startsWith(join(temp, 'chronospark-backend-repair-private-')));
    if (args[1] === 'link') return '';
    if (args[1] === 'db') {
      assert.equal(args[2], 'push');
      assert.ok(args.includes('--skip-vault'));
      assert.equal(args.some((arg) => ['--include-all', '--include-seed', '--include-roles'].includes(arg)), false);
      if (args.includes('--dry-run')) return `Would push these migrations:\n - ${MIGRATION}`;
      state.migrated = true;
      return '';
    }
    assert.deepEqual(args.slice(0, 3), ['supabase', 'functions', 'deploy']);
    const slug = args[3];
    assert.ok(FUNCTIONS.some(([name]) => name === slug));
    assert.equal(args.includes('--no-verify-jwt'), slug === 'account-delete');
    assert.ok(args.includes('--use-api'));
    state.deployed.add(slug);
    return '';
  };
  setup.options = { root: appRoot, toolingRoot: temp, request, command: run, preflight: async (passedEnv) => {
    assert.equal(passedEnv, setup.env);
    assert.equal(state.migrated, true);
    assert.equal(state.deployed.size, 3);
    if (state.preflightError) throw new Error(privateValue);
    return { schemaVersion: 1, internalAiCohortMatched: true, obsoleteDebitDenied: true,
      canonicalCreditAuthorityIntact: true, deletionCapabilityGateway: true, migrationVersion: '20260909065846' };
  } };
  setup.cleanup = () => rmSync(temp, { recursive: true, force: true });
  return setup;
}

test('rollout changes only one secret, reviewed migration and three functions in order, then verifies', async () => {
  const f = fixture();
  try {
    const receipt = await rollout(f.env, f.options);
    assert.equal(receipt.verified, true);
    assert.equal(receipt.sourceSha, source);
    assert.equal(receipt.toolingSha, toolingSource);
    assert.deepEqual(receipt.completedStages, ['baseline-and-dry-run', 'private-cohort-set', 'reviewed-migration-applied',
      'deployed-ai-proxy', 'deployed-planner-explanation', 'deployed-account-delete', 'read-only-postflight']);
    const posts = f.state.calls.filter((call) => call.method === 'POST' && !call.url.endsWith('/database/query/read-only'));
    assert.equal(posts.length, 1);
    assert.ok(posts[0].url.endsWith('/secrets'));
    const pushes = f.state.calls.filter((call) => call.args?.[1] === 'db' && !call.args.includes('--dry-run'));
    assert.equal(pushes.length, 1);
    assert.deepEqual(readdirSync(f.temp).sort(), ['chronospark-backend-repair-evidence', 'reviewed-app']);
    assert.equal(readFileSync(join(f.temp, 'reviewed-app/supabase/migrations', MIGRATION), 'utf8'), migration);
    const output = readFileSync(join(f.temp, 'chronospark-backend-repair-evidence/rollout.json'), 'utf8');
    for (const forbidden of [privateValue, env.CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS, 'synthetic-function-body']) {
      assert.equal(output.includes(forbidden), false);
    }
  } finally { f.cleanup(); }
});

test('invalid dispatch, CI, project and early migration drift perform no remote mutation', async () => {
  for (const override of [{ env: { GITHUB_SHA: 'd'.repeat(40) } }, { ci: { ...ci, conclusion: 'failure' } },
    { env: { SUPABASE_PROJECT_REF: 'wrong' } }, { dirtyApp: ' M source.ts' }, { dirtyTooling: ' M workflow.yml' },
    { driftOnRead: 1 }, { driftOnRead: 2 }, { grants: [] }, { networkError: true }]) {
    const f = fixture(override);
    try {
      await assert.rejects(rollout(f.env, f.options), (error) => !error.message.includes(privateValue));
      assert.equal(f.state.calls.some((call) => call.method === 'POST' && !call.url.endsWith('/database/query/read-only')), false);
      assert.equal(f.state.migrated, false);
      assert.equal(f.state.deployed.size, 0);
      assert.equal(readdirSync(f.temp).some((name) => name.includes('-private-')), false);
    } finally { f.cleanup(); }
  }
});

test('drift after setting cohort prevents SQL/deploy and leaves sanitized partial-state evidence', async () => {
  const f = fixture({ driftOnRead: 3 });
  try {
    await assert.rejects(rollout(f.env, f.options), /apply-reviewed-migration/);
    assert.equal(f.state.migrated, false);
    assert.equal(f.state.deployed.size, 0);
    const receipt = JSON.parse(readFileSync(join(f.temp, 'chronospark-backend-repair-evidence/rollout.json')));
    assert.equal(receipt.verified, false);
    assert.deepEqual(receipt.completedStages, ['baseline-and-dry-run', 'private-cohort-set']);
  } finally { f.cleanup(); }
});

test('secret API and postflight failures never expose response or exception text and clean private files', async () => {
  for (const override of [{ secretFailure: true }, { preflightError: true }]) {
    const f = fixture(override);
    try {
      await assert.rejects(rollout(f.env, f.options), (error) => !error.message.includes(privateValue));
      const output = readFileSync(join(f.temp, 'chronospark-backend-repair-evidence/rollout.json'), 'utf8');
      assert.equal(output.includes(privateValue), false);
      assert.equal(JSON.parse(output).verified, false);
      assert.equal(readdirSync(f.temp).some((name) => name.includes('-private-')), false);
      if (override.secretFailure) assert.equal(f.state.migrated, false);
    } finally { f.cleanup(); }
  }
});

test('real child failure sanitizes both output channels instead of echoing private diagnostics', () => {
  assert.throws(() => command([process.execPath, '-e',
    'process.stdout.write(process.env.FIXTURE_PRIVATE);process.stderr.write(process.env.FIXTURE_PRIVATE);process.exit(1)'],
  root, { ...process.env, FIXTURE_PRIVATE: privateValue }), (error) => !error.message.includes(privateValue));
});

test('existing scheduled and default reconciliation remain separate from branch-bound repair dispatch', () => {
  const workflow = readFileSync(join(root, '.github/workflows/backend-reconciliation.yml'), 'utf8');
  assert.match(workflow, /cron: '\*\/10 \* \* \* \*'/);
  assert.match(workflow, /default: reconcile/);
  assert.match(workflow, /account-deletion:\s+if: github.event_name == 'schedule' \|\| \(github.event_name == 'workflow_dispatch' && inputs.operation == 'reconcile'\)/);
  assert.match(workflow, /reviewed-repairs:\s+if: github.event_name == 'workflow_dispatch' && inputs.operation == 'apply-reviewed-repairs' && github.repository == 'ghostheart5\/fantastic-guacamole' && github.ref == 'refs\/heads\/fix\/app-only-readiness-priority2-20260902'/);
  const repair = workflow.split('  reviewed-repairs:')[1];
  assert.match(repair, /environment: production/);
  assert.match(repair, /version: 2\.116\.0/);
  assert.equal(repair.includes('account-delete-reconcile'), false);
  assert.equal(repair.includes('RECONCILE_SECRET'), false);
  assert.equal(repair.includes('secrets.CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS'), true);
  assert.match(repair, /ref: \$\{\{ github.sha \}\}\s+path: tooling/);
  assert.match(repair, /ref: \$\{\{ inputs.source_sha \}\}\s+path: candidate/);
  assert.ok(repair.indexOf('(.id | tostring) == $run') < repair.indexOf('path: candidate'));
  assert.ok(repair.indexOf('.head_sha == $sha') < repair.indexOf('SUPABASE_ACCESS_TOKEN:'));
  assert.match(repair, /run: node candidate\/scripts\/backend_repair_rollout.mjs candidate tooling/);
});
