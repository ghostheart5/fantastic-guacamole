import test from 'node:test';
import assert from 'node:assert/strict';
import {
  parseRefundReconciliationCounts,
  runPublicCreditRefundReconciliation,
} from './reconcile_public_credit_refunds.mjs';

const env = {
  AXIOMARA_PUBLIC_CREDIT_REFUNDS_ENABLED: 'true',
  CHRONOSPARK_SUPABASE_URL: 'https://qpwhuckyirnqtmvhpede.supabase.co',
  PUBLIC_CREDIT_REFUND_RECONCILE_SECRET: 'synthetic-test-secret',
};
const empty = { scanned: 0, refunded: 0, requested: 0, pending: 0, manualReview: 0, retryLater: 0 };

test('disabled, malformed and wrong-project configurations cannot call the refund worker', async () => {
  for (const patch of [
    { AXIOMARA_PUBLIC_CREDIT_REFUNDS_ENABLED: undefined },
    { AXIOMARA_PUBLIC_CREDIT_REFUNDS_ENABLED: 'false' },
    { AXIOMARA_PUBLIC_CREDIT_REFUNDS_ENABLED: 'TRUE' },
    { CHRONOSPARK_SUPABASE_URL: 'https://other.supabase.co' },
    { PUBLIC_CREDIT_REFUND_RECONCILE_SECRET: '' },
  ]) {
    await assert.rejects(runPublicCreditRefundReconciliation({ ...env, ...patch }, () => {
      assert.fail('disabled or misconfigured caller made a request');
    }), /disabled or not configured/);
  }
});

test('authorized caller sends one fixed POST and returns only aggregate counts', async () => {
  let calls = 0;
  const result = await runPublicCreditRefundReconciliation(env, async (url, init) => {
    calls++;
    assert.equal(url, `${env.CHRONOSPARK_SUPABASE_URL}/functions/v1/public-credit-refund-reconcile`);
    assert.equal(init.method, 'POST');
    assert.equal(init.body, '{}');
    assert.equal(init.redirect, 'error');
    assert.equal(init.headers['x-axiomara-refund-reconcile-secret'], env.PUBLIC_CREDIT_REFUND_RECONCILE_SECRET);
    return Response.json({ ...empty, scanned: 1, requested: 1, orderId: 'private', token: 'private' });
  });
  assert.equal(calls, 1);
  assert.deepEqual(result, { ...empty, scanned: 1, requested: 1, requiresAttention: false });
  assert.equal(result.refunded, 0, 'requested must not imply provider-confirmed refund');
});

test('uncertain transport and HTTP failures are never automatically retried', async () => {
  for (const mode of ['timeout', 'http']) {
    let calls = 0;
    await assert.rejects(runPublicCreditRefundReconciliation(env, async () => {
      calls++;
      if (mode === 'timeout') throw new Error('synthetic timeout');
      return new Response('private provider details', { status: 502 });
    }), mode === 'timeout' ? /synthetic timeout/ : /^Error: Refund reconciliation failed \(502\)$/);
    assert.equal(calls, 1);
  }
});

test('invalid counts fail closed and manual or deferred outcomes require attention', async () => {
  for (const body of [null, [], {}, { ...empty, scanned: -1 },
    { ...empty, scanned: 6, requested: 6 }, { ...empty, scanned: 1 },
    { ...empty, refunded: 1 }, { ...empty, scanned: 1, refunded: 0.5 }]) {
    assert.throws(() => parseRefundReconciliationCounts(body));
  }
  for (const outcome of ['manualReview', 'retryLater']) {
    const result = await runPublicCreditRefundReconciliation(env, async () =>
      Response.json({ ...empty, scanned: 1, [outcome]: 1 }));
    assert.equal(result.requiresAttention, true);
  }
});
