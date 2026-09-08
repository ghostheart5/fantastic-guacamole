import test from 'node:test';
import assert from 'node:assert/strict';
import { googleCredentialFingerprint, verifyCatalog, verifyInternalBillingBackend, verifyRtdnTestDelivery } from './verify_internal_billing_backend.mjs';

function catalog() {
  const products = [['monthly', 'P1M', '7'], ['annual', 'P1Y', '69']].map(([base, period, units]) => ({
    packageName: 'com.ghostheart5.chronospark', productId: `chronospark_premium_${base}`,
    basePlans: [{ basePlanId: base, state: 'ACTIVE',
      autoRenewingBasePlanType: { billingPeriodDuration: period },
      regionalConfigs: [{ regionCode: 'US', newSubscriberAvailability: true,
        price: { currencyCode: 'USD', units, nanos: 990000000 } }],
    }],
  }));
  const rows = products.map((p, index) => ({
    id: index === 0 ? 'premium_monthly' : 'premium_yearly', product_id: p.productId,
    currency_code: 'USD', price_micros: index === 0 ? 7990000 : 69990000,
    credits_per_period: 300, is_active: true,
  }));
  return { products, rows };
}

test('approved monthly and annual catalog matches both authorities', () => {
  const { products, rows } = catalog();
  assert.doesNotThrow(() => verifyCatalog(products, rows));
});

test('price, duration, product, country and backend drift stop the build', () => {
  for (const mutate of [
    (p) => p[0].basePlans[0].regionalConfigs[0].price.units = '6',
    (p) => p[1].basePlans[0].autoRenewingBasePlanType.billingPeriodDuration = 'P1M',
    (p) => p[0].packageName = 'other.app',
    (p) => p[0].basePlans[0].state = 'DRAFT',
    (p) => p[0].basePlans[0].regionalConfigs[0].newSubscriberAvailability = false,
    (p) => p[0].basePlans[0].otherRegionsConfig = { newSubscriberAvailability: true },
    (_, r) => r[0].price_micros = 0,
    (_, r) => r[1].credits_per_period = 4000,
  ]) {
    const { products, rows } = catalog();
    mutate(products, rows);
    assert.throws(() => verifyCatalog(products, rows));
  }
});

test('only the approved US prepaid license-test plan may accompany monthly', () => {
  const { products, rows } = catalog();
  const prepaid = structuredClone(products[0].basePlans[0]);
  prepaid.basePlanId = 'monthly-prepaid-test';
  delete prepaid.autoRenewingBasePlanType;
  prepaid.prepaidBasePlanType = { billingPeriodDuration: 'P1M' };
  products[0].basePlans.push(prepaid);
  assert.doesNotThrow(() => verifyCatalog(products, rows));
  for (const mutate of [
    (p) => p.basePlanId = 'unreviewed-plan',
    (p) => p.prepaidBasePlanType.billingPeriodDuration = 'P1Y',
    (p) => p.autoRenewingBasePlanType = { billingPeriodDuration: 'P1M' },
    (p) => p.regionalConfigs[0].price.units = '9',
    (p) => p.regionalConfigs[0].regionCode = 'CA',
    (p) => p.otherRegionsConfig = { newSubscriberAvailability: true },
  ]) {
    const changed = structuredClone(products);
    mutate(changed[0].basePlans[1]);
    assert.throws(() => verifyCatalog(changed, rows));
  }
});

test('preflight rejects an old verifier before touching Google credentials', async () => {
  let calls = 0;
  await assert.rejects(verifyInternalBillingBackend({
    SUPABASE_PROJECT_REF: 'a'.repeat(20),
    CHRONOSPARK_SUPABASE_URL: `https://${'a'.repeat(20)}.supabase.co`,
    CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT: `https://${'a'.repeat(20)}.supabase.co/functions/v1/verify-receipt`,
    SUPABASE_SECRET_KEY: 'synthetic',
  }, async (url, init) => {
    calls++;
    assert.equal(init.redirect, 'error');
    assert.equal(init.method, undefined);
    return new Response('', { status: 405, headers: { 'x-chronospark-contract': 'verify-receipt-v2' } });
  }), /lacks the license-test guard/);
  assert.equal(calls, 1);
});

test('RTDN gate requires a recent processed test for the exact app', () => {
  const now = Date.parse('2026-09-07T05:00:00Z');
  const event = {
    package_name: 'com.ghostheart5.chronospark', event_type: 'test',
    state: 'processed', failure_code: null,
    received_at: '2026-09-07T04:00:00Z', processed_at: '2026-09-07T04:00:01Z',
  };
  assert.equal(verifyRtdnTestDelivery([event], now).processedAt, '2026-09-07T04:00:01.000Z');
  assert.throws(() => verifyRtdnTestDelivery([], now));
  for (const overrides of [
    { package_name: 'other.app' }, { event_type: 'subscription' },
    { state: 'failed' }, { failure_code: 'unauthorized' },
    { received_at: '2026-09-06T04:00:00Z' }, { processed_at: null },
    { processed_at: '2026-09-07T03:00:00Z' }, { processed_at: '2026-09-08T04:00:00Z' },
  ]) {
    assert.throws(() => verifyRtdnTestDelivery([{ ...event, ...overrides }], now));
  }
});

test('credential comparison ignores JSON metadata and PEM whitespace but detects identity or key changes', () => {
  const account = { client_email: 'synthetic@example.invalid', private_key: '-----BEGIN PRIVATE KEY-----\nU1lOVEhFVElD\n-----END PRIVATE KEY-----\n' };
  const fingerprint = googleCredentialFingerprint(account);
  assert.equal(googleCredentialFingerprint({ ...account, project_id: 'unused', private_key: account.private_key.replaceAll('\n', '\r\n') }), fingerprint);
  assert.notEqual(googleCredentialFingerprint({ ...account, client_email: 'other@example.invalid' }), fingerprint);
  assert.notEqual(googleCredentialFingerprint({ ...account, private_key: 'DIFFERENT' }), fingerprint);
  assert.throws(() => googleCredentialFingerprint({ client_email: account.client_email }));
});
