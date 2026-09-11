import { test } from 'node:test';
import assert from 'node:assert/strict';
import { combineCohort, validateRun } from './reviewer_cohort.mjs';
const a = 'a'.repeat(64), b = 'b'.repeat(64);
test('preserves all existing accounts and canonicalizes ordering', () => {
  assert.equal(combineCohort(b, a), `${a},${b}`);
  assert.equal(combineCohort(`${b},${a}`, a), `${a},${b}`);
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
