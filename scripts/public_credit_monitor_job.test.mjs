import test from 'node:test';
import assert from 'node:assert/strict';
import { runPublicCreditMonitor, monitorSummary } from './public_credit_monitor_job.mjs';

const env = {
  SUPABASE_PROJECT_REF: 'qpwhuckyirnqtmvhpede',
  CHRONOSPARK_SUPABASE_URL: 'https://qpwhuckyirnqtmvhpede.supabase.co',
  SUPABASE_SECRET_KEY: 'synthetic-private-key',
};
const clear = {
  awaiting: 0, awaitingOverOneHour: 0, awaitingOverOneDay: 0,
  oldestAwaitingAt: null, refunded: 0, fulfilled: 0,
};

test('alert drill reaches the overdue classifier without credentials or network access', async () => {
  const result = await runPublicCreditMonitor('alert-drill', {}, () => assert.fail('drill made a network call'));
  assert.equal(result.evidenceKind, 'synthetic-alert-drill');
  assert.equal(result.status, 'action_required');
  assert.equal(result.exitCode, 2);
  assert.match(monitorSummary(result), /Synthetic drill/);
  assert.match(monitorSummary(result), /exact run/);
});

test('read-only monitor works while refund and public-sale flags are absent', async () => {
  let calls = 0;
  const result = await runPublicCreditMonitor('check', env, async (url, options) => {
    calls++;
    assert.equal(url, `${env.CHRONOSPARK_SUPABASE_URL}/rest/v1/rpc/public_credit_checkout_resolution_health`);
    assert.equal(options.body, '{}');
    return Response.json({ ...clear, orderId: 'private-order', token: 'private-token' });
  });
  assert.equal(calls, 1);
  assert.equal(result.status, 'clear');
  assert.equal(result.exitCode, 0);
  assert.doesNotMatch(JSON.stringify(result), /private/);
});

test('overdue and critical live aggregates fail with an actionable summary', async () => {
  for (const days of [0, 1]) {
    const result = await runPublicCreditMonitor('check', env, async () => Response.json({
      ...clear, awaiting: 1, awaitingOverOneHour: 1, awaitingOverOneDay: days,
      oldestAwaitingAt: '2026-09-24T00:00:00Z',
    }));
    assert.equal(result.status, days ? 'critical' : 'action_required');
    assert.equal(result.exitCode, 2);
    assert.match(monitorSummary(result), /Never retry an uncertain refund/);
  }
});

test('failed or malformed reads are unknown and redact transport details', async () => {
  for (const request of [
    async () => { throw new Error('private-key and private-order'); },
    async () => new Response('private-order', { status: 503 }),
    async () => Response.json({ ...clear, awaitingOverOneHour: 1 }),
  ]) {
    const result = await runPublicCreditMonitor('check', env, request);
    assert.equal(result.status, 'unknown');
    assert.equal(result.exitCode, 1);
    assert.equal(result.awaiting, undefined);
    assert.doesNotMatch(JSON.stringify(result) + monitorSummary(result), /private-key|private-order/);
  }
});

test('unknown mode is rejected before any network request', async () => {
  await assert.rejects(runPublicCreditMonitor('refund', env, () => assert.fail('invalid mode fetched')));
});
