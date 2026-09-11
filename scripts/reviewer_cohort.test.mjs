import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { combineCohort, validateRun, prepare } from './reviewer_cohort.mjs';
const a = 'a'.repeat(64), b = 'b'.repeat(64);
test('preserves all existing accounts and canonicalizes ordering', () => {
  assert.equal(combineCohort(b, a), `${a},${b}`);
  assert.equal(combineCohort(`${b},${a}`, a), `${a},${b}`);
});
test('live preparation verifies evidence and identity before the single scoped mutation', async () => {
  const hash = (v) => createHash('sha256').update(v).digest('hex');
  const previous = process.cwd(), temp = mkdtempSync(join(tmpdir(), 'review-cohort-contract-'));
  const sha = 'a'.repeat(40), key = 'CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS';
  const env = { GITHUB_ACTIONS: 'true', GITHUB_EVENT_NAME: 'workflow_dispatch',
    GITHUB_REPOSITORY: 'ghostheart5/fantastic-guacamole',
    GITHUB_REF: 'refs/heads/fix/app-only-readiness-priority2-20260902',
    SUPABASE_PROJECT_REF: 'qpwhuckyirnqtmvhpede', SUPABASE_ACCESS_TOKEN: 'private-fixture', GH_TOKEN: 'private-fixture',
    [key]: a, CHRONOSPARK_REVIEWER_ACCOUNT_DIGEST: b, REVIEW_SOURCE_SHA: sha,
    REVIEW_CI_RUN: '123', REVIEW_DB_RUN: '124', RUNNER_TEMP: temp };
  mkdirSync(join(temp, 'candidate/tool'), { recursive: true });
  const policy = { assistant_release_stage: 'internal', assistant_release_internal_account_digests: '' };
  writeFileSync(join(temp, 'candidate/tool/internal_testing_assistant_release.json'), JSON.stringify(policy));
  process.chdir(temp);
  try {
    for (const failure of ['none', 'database', 'identity', 'prior-cohort']) {
      let writes = 0;
      const request = async (url, init) => {
        assert.equal(init.redirect, 'error');
        if (url.includes('api.github.com')) {
          const db = url.endsWith('/124');
          return Response.json({ id: db ? 124 : 123, head_sha: sha,
            repository: { full_name: env.GITHUB_REPOSITORY }, event: 'workflow_dispatch', status: 'completed',
            conclusion: db && failure === 'database' ? 'failure' : 'success',
            path: db ? '.github/workflows/supabase-database.yml' : '.github/workflows/ci.yml' });
        }
        assert.ok(url.startsWith('https://api.supabase.com/v1/projects/qpwhuckyirnqtmvhpede/'));
        if (url.endsWith('/database/query/read-only')) return Response.json([{ digest: failure === 'identity' ? a : b }]);
        assert.ok(url.endsWith('/secrets'));
        if (init.method === 'POST') {
          writes++;
          assert.deepEqual(JSON.parse(init.body), [{ name: key, value: `${a},${b}` }]);
          return Response.json({}, { status: 201 });
        }
        return Response.json([{ name: key, value: failure === 'prior-cohort' ? hash('drift') : hash(writes ? `${a},${b}` : a) }]);
      };
      if (failure === 'none') {
        const receipt = await prepare(env, request);
        assert.equal(writes, 1); assert.equal(receipt.verified, true); assert.equal(receipt.cohortCount, 2);
        const output = readFileSync(join(temp, 'reviewer-cohort.json'), 'utf8');
        for (const value of [a, b, 'private-fixture', 'mock@']) assert.ok(!output.includes(value));
        assert.equal(receipt.policySha256, hash(JSON.stringify({ assistant_release_internal_account_digests: `${a},${b}`, assistant_release_stage: 'internal' })));
      } else {
        await assert.rejects(prepare(env, request)); assert.equal(writes, 0);
      }
    }
  } finally { process.chdir(previous); rmSync(temp, { recursive: true, force: true }); }
});
for (const [name, original, reviewer] of [
  ['empty prior cohort', '', a], ['duplicate prior accounts', `${a},${a}`, b],
  ['malformed reviewer', a, 'email@example.invalid'], ['missing reviewer', a, undefined],
  ['invalid prior account', 'unknown', a], ['whitespace', a, ` ${b}`],
]) test(name, () => assert.throws(() => combineCohort(original, reviewer)));
test('requires matching successful exact-source manual evidence', () => {
  const sha = 'a'.repeat(40), path = '.github/workflows/ci.yml';
  const run = { id: 123, head_sha: sha, path, repository: { full_name: 'ghostheart5/fantastic-guacamole' },
    event: 'workflow_dispatch', status: 'completed', conclusion: 'success' };
  validateRun(run, '123', sha, path);
  for (const field of ['id', 'head_sha', 'path', 'event', 'status', 'conclusion']) {
    assert.throws(() => validateRun({ ...run, [field]: 'wrong' }, '123', sha, path));
  }
});
