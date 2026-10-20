import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { runLicenseRefundGate, validateLicenseRefundGateContext,
  validateLicenseRefundServer } from './run_credit_refund_license_gate.mjs';

const hash = (value) => createHash('sha256').update(value).digest('hex');
const target = 'a'.repeat(64);
const env = {
  GITHUB_ACTIONS: 'true', GITHUB_EVENT_NAME: 'workflow_dispatch',
  GITHUB_REPOSITORY: 'ghostheart5/fantastic-guacamole',
  GITHUB_REF: 'refs/heads/fix/app-only-readiness-priority2-20260902',
  LICENSE_REFUND_OPERATION: 'test-credit-refund',
  LICENSE_REFUND_SOURCE_SHA: 'b'.repeat(40), LICENSE_REFUND_CHECKOUT_SHA: 'b'.repeat(40),
  LICENSE_REFUND_CI_RUN: '12345', LICENSE_REFUND_SCOPE_DIGEST: hash(target),
  LICENSE_REFUND_WORKER_SHA256: 'c'.repeat(64),
  CHRONOSPARK_SUPABASE_URL: 'https://qpwhuckyirnqtmvhpede.supabase.co',
  SUPABASE_ACCESS_TOKEN: 'synthetic-management-token',
  PUBLIC_CREDIT_REFUND_RECONCILE_SECRET: 'synthetic-refund-secret',
};
const ci = { id: 12345, head_sha: env.LICENSE_REFUND_SOURCE_SHA,
  repository: { full_name: env.GITHUB_REPOSITORY }, path: '.github/workflows/ci.yml',
  event: 'workflow_dispatch', status: 'completed', conclusion: 'success' };
const secrets = [
  { name: 'PUBLIC_CREDIT_AUTO_REFUND_ENABLED', value: hash('true') },
  { name: 'PUBLIC_CREDIT_REFUND_TEST_ONLY', value: hash('true') },
  { name: 'PUBLIC_CREDIT_REFUND_TEST_TOKEN_HASH', value: hash(target) },
];
const functions = [{ slug: 'public-credit-refund-reconcile', status: 'ACTIVE',
  verify_jwt: false, ezbr_sha256: env.LICENSE_REFUND_WORKER_SHA256, version: 7 }];
const counts = { scanned: 1, refunded: 0, requested: 1, pending: 0, manualReview: 0, retryLater: 0 };

test('manual license invocation requires protected context, exact green CI and schedule off', () => {
  validateLicenseRefundGateContext(env, ci);
  for (const patch of [
    { GITHUB_EVENT_NAME: 'schedule' }, { GITHUB_REF: 'refs/heads/main' },
    { GITHUB_REPOSITORY: 'other/repo' }, { LICENSE_REFUND_OPERATION: 'reconcile' },
    { LICENSE_REFUND_CHECKOUT_SHA: 'd'.repeat(40) }, { LICENSE_REFUND_CI_RUN: '999' },
    { LICENSE_REFUND_SCOPE_DIGEST: '' }, { LICENSE_REFUND_WORKER_SHA256: 'bad' },
    { AXIOMARA_PUBLIC_CREDIT_REFUNDS_ENABLED: 'true' }, { SUPABASE_ACCESS_TOKEN: '' },
  ]) assert.throws(() => validateLicenseRefundGateContext({ ...env, ...patch }, ci));
  for (const patch of [{ conclusion: 'failure' }, { status: 'in_progress' },
    { event: 'push' }, { head_sha: 'd'.repeat(40) }, { path: '.github/workflows/other.yml' }]) {
    assert.throws(() => validateLicenseRefundGateContext(env, { ...ci, ...patch }));
  }
});

test('server guard rejects missing scope, public sales, duplicates and worker drift', () => {
  assert.equal(validateLicenseRefundServer(env, secrets, functions), 7);
  for (const state of [
    secrets.slice(0, 2), secrets.filter((s) => !s.name.endsWith('TEST_ONLY')),
    [...secrets, secrets[0]],
    secrets.map((s) => s.name.endsWith('TEST_TOKEN_HASH') ? { ...s, value: 'd'.repeat(64) } : s),
    [...secrets, { name: 'CHRONOSPARK_PUBLIC_CREDIT_TOPUPS_ENABLED', value: hash('true') }],
    [...secrets, { name: 'CHRONOSPARK_PUBLIC_BILLING_REVIEW_APPROVED', value: hash('true') }],
  ]) assert.throws(() => validateLicenseRefundServer(env, state, functions));
  for (const patch of [{ ezbr_sha256: 'd'.repeat(64) }, { status: 'INACTIVE' }, { verify_jwt: true }]) {
    assert.throws(() => validateLicenseRefundServer(env, secrets, [{ ...functions[0], ...patch }]));
  }
});

test('license gate only reads configuration then makes one fixed scoped-worker POST', async () => {
  const calls = [];
  const result = await runLicenseRefundGate(env, ci, async (url, init) => {
    calls.push({ url, method: init.method ?? 'GET' });
    assert.equal(init.redirect, 'error');
    if (url.endsWith('/secrets')) return Response.json(secrets);
    if (url.endsWith('/functions')) return Response.json(functions);
    assert.equal(url, `${env.CHRONOSPARK_SUPABASE_URL}/functions/v1/public-credit-refund-reconcile`);
    assert.equal(init.body, '{}');
    return Response.json({ ...counts, privateOrderId: 'must-not-escape' });
  });
  assert.deepEqual(calls.map((c) => c.method), ['GET', 'GET', 'POST']);
  assert.equal(result.requested, 1);
  assert.equal(result.refunded, 0);
  assert.equal(result.mode, 'license_test_only');
  assert.equal(JSON.stringify(result).includes('must-not-escape'), false);
  assert.equal(env.AXIOMARA_PUBLIC_CREDIT_REFUNDS_ENABLED, undefined);
});

test('configuration refusal never calls worker and uncertain POST is never repeated', async () => {
  for (const unsafe of [true, false]) {
    let posts = 0;
    await assert.rejects(runLicenseRefundGate(env, ci, async (url) => {
      if (url.endsWith('/secrets')) return Response.json(unsafe ? [] : secrets);
      if (url.endsWith('/functions')) return Response.json(functions);
      posts++;
      throw new Error('synthetic lost response');
    }));
    assert.equal(posts, unsafe ? 0 : 1);
  }
});

test('an empty queue cannot be recorded as a successful license worker test', async () => {
  await assert.rejects(runLicenseRefundGate(env, ci, async (url) => {
    if (url.endsWith('/secrets')) return Response.json(secrets);
    if (url.endsWith('/functions')) return Response.json(functions);
    return Response.json({ ...counts, scanned: 0, requested: 0 });
  }));
});
