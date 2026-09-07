import test from 'node:test';
import assert from 'node:assert/strict';
import { verifyCatalog, verifyInternalBillingBackend } from './verify_internal_billing_backend.mjs';

function catalog() {
  const products = [['monthly', 'P1M', '4'], ['annual', 'P1Y', '39']].map(([base, period, units]) => ({
    packageName: 'com.ghostheart5.chronospark', productId: `chronospark_premium_${base}`,
    basePlans: [{ basePlanId: base, state: 'ACTIVE',
      autoRenewingBasePlanType: { billingPeriodDuration: period },
      regionalConfigs: [{ regionCode: 'US', newSubscriberAvailability: true,
        price: { currencyCode: 'USD', units, nanos: 990000000 } }],
    }],
  }));
  const rows = products.map((p, index) => ({
    id: index === 0 ? 'premium_monthly' : 'premium_yearly', product_id: p.productId,
    currency_code: 'USD', price_micros: index === 0 ? 4990000 : 39990000,
    credits_per_period: index === 0 ? 300 : 360, is_active: true,
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
