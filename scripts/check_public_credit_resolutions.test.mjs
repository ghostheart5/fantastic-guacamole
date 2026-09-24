import test from 'node:test';
import assert from 'node:assert/strict';
import {
  classifyPublicCreditResolutionHealth,
  readPublicCreditResolutionHealth,
} from './check_public_credit_resolutions.mjs';

const project = 'qpwhuckyirnqtmvhpede';
const env = {
  SUPABASE_PROJECT_REF: project,
  CHRONOSPARK_SUPABASE_URL: `https://${project}.supabase.co`,
  SUPABASE_SECRET_KEY: 'synthetic-service-key',
};
const clear = {
  awaiting: 0, awaitingOverOneHour: 0, awaitingOverOneDay: 0,
  oldestAwaitingAt: null, refunded: 1, fulfilled: 0,
};

test('aggregate monitor escalates overdue paid orders without returning identifiers', () => {
  assert.equal(classifyPublicCreditResolutionHealth(clear).status, 'clear');
  assert.equal(classifyPublicCreditResolutionHealth({
    ...clear, awaiting: 1, oldestAwaitingAt: '2026-09-24T12:00:00Z',
  }).status, 'watch');
  assert.equal(classifyPublicCreditResolutionHealth({
    ...clear, awaiting: 1, awaitingOverOneHour: 1,
    oldestAwaitingAt: '2026-09-24T10:00:00Z',
  }).status, 'action_required');
  const health = classifyPublicCreditResolutionHealth({
    ...clear, awaiting: 1, awaitingOverOneHour: 1, awaitingOverOneDay: 1,
    oldestAwaitingAt: '2026-09-23T10:00:00Z',
    token_hash: 'secret', order_id: 'GPA.secret', billing_principal_id: 'secret',
  });
  assert.equal(health.status, 'critical');
  assert.equal(JSON.stringify(health).includes('secret'), false);
});

test('monitor rejects incomplete or contradictory aggregates', () => {
  for (const bad of [null, [], {}, { ...clear, awaiting: -1 },
    { ...clear, awaitingOverOneDay: 1 },
    { ...clear, awaiting: 1, oldestAwaitingAt: null },
    { ...clear, oldestAwaitingAt: '2026-09-24T12:00:00Z' }]) {
    assert.throws(() => classifyPublicCreditResolutionHealth(bad));
  }
});

test('monitor calls only the fixed service-only read and redacts HTTP failures', async () => {
  let calls = 0;
  const health = await readPublicCreditResolutionHealth(env, async (url, init) => {
    calls += 1;
    assert.equal(url, `https://${project}.supabase.co/rest/v1/rpc/public_credit_checkout_resolution_health`);
    assert.equal(init.method, 'POST');
    assert.equal(init.body, '{}');
    assert.equal(init.headers.apikey, env.SUPABASE_SECRET_KEY);
    return Response.json(clear);
  });
  assert.equal(calls, 1);
  assert.equal(health.status, 'clear');
  await assert.rejects(readPublicCreditResolutionHealth(env, async () =>
    new Response('private provider response', { status: 403 })),
  /Credit-resolution health read failed \(403\)/);
  await assert.rejects(readPublicCreditResolutionHealth({ ...env, SUPABASE_PROJECT_REF: 'other' },
    async () => { throw new Error('must not fetch'); }), /project or credential/);
});
