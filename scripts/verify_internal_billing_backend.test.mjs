import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash, generateKeyPairSync } from 'node:crypto';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { CREDIT_AUTHORITY_FUNCTIONS } from './verify_backend_repair_gate.mjs';
import { googleCredentialFingerprint, internalBillingCohortFingerprint, loadBackendTestProfile, validateBackendTestProfile, verifyCatalog, verifyCreditAdmissionBackend, verifyCreditPackCatalog, verifyInternalBillingBackend, verifyRtdnTestDelivery } from './verify_internal_billing_backend.mjs';

const billingDigest = 'a'.repeat(64);

const publicTestProfile = () => ({ schemaVersion: 1, backendProfile: 'public_license_test',
  reviewedBillingCohortSha256: internalBillingCohortFingerprint(billingDigest) });

test('versioned backend profile is strict, canonical and absent defaults to contained', () => {
  const folder = mkdtempSync(join(tmpdir(), 'billing-profile-'));
  const path = join(folder, 'profile.json');
  try {
    assert.equal(loadBackendTestProfile(path).backendProfile, 'contained');
    writeFileSync(path, JSON.stringify(publicTestProfile()) + '\n');
    assert.deepEqual(loadBackendTestProfile(path), publicTestProfile());
    for (const bad of [
      { ...publicTestProfile(), schemaVersion: 2 },
      { ...publicTestProfile(), backendProfile: 'auto' },
      { ...publicTestProfile(), extra: true },
      { ...publicTestProfile(), reviewedBillingCohortSha256: '' },
      { ...publicTestProfile(), reviewedBillingCohortSha256: 'A'.repeat(64) },
      { ...publicTestProfile(), backendProfile: 'contained' },
    ]) assert.throws(() => validateBackendTestProfile(bad));
    for (const text of ['{', JSON.stringify(publicTestProfile(), null, 2),
      '{"schemaVersion":0,' + JSON.stringify(publicTestProfile()).slice(1)]) {
      writeFileSync(path, text);
      assert.throws(() => loadBackendTestProfile(path));
    }
  } finally { rmSync(folder, { recursive: true }); }
});

test('public compatibility cannot be inferred from headers or entered without both license-test flags', async () => {
  for (const env of [{}, { CANDIDATE_BILLING_TEST: 'true' },
    { CANDIDATE_CREDIT_ADMISSION_QA: 'true' },
    { CANDIDATE_BILLING_TEST: true, CANDIDATE_CREDIT_ADMISSION_QA: 'true' }]) {
    let calls = 0;
    await assert.rejects(verifyInternalBillingBackend(env, async () => { calls++; }, publicTestProfile()),
      /requires billing and private credit admission QA/);
    assert.equal(calls, 0);
  }
});

function publicFixture() {
  const project = 'a'.repeat(20), root = `https://${project}.supabase.co`;
  const privateKey = generateKeyPairSync('rsa', { modulusLength: 2048 }).privateKey
    .export({ type: 'pkcs8', format: 'pem' });
  const account = { client_email: 'synthetic@example.invalid', private_key: privateKey,
    token_uri: 'https://oauth2.googleapis.com/token' };
  const cohort = internalBillingCohortFingerprint(billingDigest);
  const env = { SUPABASE_PROJECT_REF: project, CHRONOSPARK_SUPABASE_URL: root,
    CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT: `${root}/functions/v1/verify-receipt`,
    SUPABASE_SECRET_KEY: 'synthetic-service', SUPABASE_ACCESS_TOKEN: 'synthetic-management',
    CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS: billingDigest, GOOGLE_SERVICE_ACCOUNT_JSON: JSON.stringify(account),
    CANDIDATE_BILLING_TEST: 'true', CANDIDATE_CREDIT_ADMISSION_QA: 'true' };
  const state = { receiptStatus: 405, contract: 'verify-receipt-v2', checkout: 'enabled-v1',
    qa: 'cohort-v1', cohort, google: googleCredentialFingerprint(account), rtdnFresh: true };
  const calls = [];
  const { products, rows } = catalog();
  const packs = [{ id: 'credits_100', credits: 100, units: '2', micros: 2990000 },
    { id: 'credits_300', credits: 300, units: '7', micros: 7990000 }];
  const functions = [['ai-proxy', true], ['planner-explanation', true], ['account-delete', false],
    ['verify-receipt', true], ['google-play-rtdn', false]]
    .map(([slug, verify_jwt]) => ({ slug, verify_jwt, status: 'ACTIVE', version: 1 }));
  const headers = () => ({ 'x-chronospark-contract': state.contract,
    'x-chronospark-public-credit-checkout': state.checkout,
    'x-chronospark-credit-admission-qa': state.qa,
    'x-chronospark-internal-billing-cohort-sha256': state.cohort,
    'x-chronospark-google-credential-sha256': state.google });
  const request = async (url, init) => {
    calls.push({ url, method: init.method ?? 'GET' });
    assert.equal(init.redirect, 'error');
    const path = new URL(url).pathname;
    if (path.endsWith('/verify-receipt')) {
      assert.equal(init.method, undefined);
      return new Response('', { status: state.receiptStatus, headers: headers() });
    }
    if (url.startsWith('https://api.supabase.com/')) {
      if (path.endsWith('/functions')) return Response.json(functions);
      if (path.endsWith('/database/migrations')) return Response.json([
        { version: '20260909065846' }, { version: '20260924030236' }]);
      assert.ok(path.endsWith('/database/query/read-only'));
      assert.equal(init.method, 'POST');
      return Response.json(CREDIT_AUTHORITY_FUNCTIONS.flatMap((signature, i) =>
        ['anon', 'authenticated', 'service_role'].map((role_name) =>
          ({ signature, role_name, present: true, can_execute: i !== 0 && role_name === 'service_role' }))));
    }
    if (path.endsWith('/ai-proxy') || path.endsWith('/planner-explanation')) {
      assert.equal(init.method, undefined, 'Preflight must never submit paid inference.');
      return new Response('', { status: 405, headers: {
        'x-chronospark-contract': path.endsWith('/ai-proxy') ? 'ai-proxy-v2' : 'planner-explanation-v1',
        'x-chronospark-internal-ai-guard': 'v1', 'x-chronospark-internal-ai-cohort-sha256': cohort } });
    }
    if (path.endsWith('/account-delete')) {
      assert.equal(init.method, 'POST');
      assert.equal(new Headers(init.headers).has('authorization'), false);
      const body = JSON.parse(init.body);
      const malformed = body.requestId === 'invalid';
      return Response.json({ error: body.action === 'delete' ? 'unauthorized' :
        malformed ? 'invalid_status_capability' : 'deletion_request_not_found' },
      { status: body.action === 'delete' ? 401 : malformed ? 400 : 404,
        headers: { 'x-chronospark-contract': 'account-delete-v2' } });
    }
    if (url === account.token_uri) return Response.json({ access_token: 'synthetic-google-token' });
    if (url.startsWith('https://androidpublisher.googleapis.com/')) {
      assert.equal(init.method, undefined, 'No Play writes or purchases in preflight.');
      if (path.includes('/subscriptions/')) return Response.json(products.find((p) => path.endsWith('/' + p.productId)));
      const pack = packs.find((p) => path.endsWith('/chronospark_' + p.id));
      assert.ok(pack);
      return Response.json({ packageName: 'com.ghostheart5.chronospark', productId: 'chronospark_' + pack.id,
        purchaseOptions: [{ state: 'ACTIVE', buyOption: { legacyCompatible: true, multiQuantityEnabled: false },
          regionalPricingAndAvailabilityConfigs: [{ regionCode: 'US', availability: 'AVAILABLE',
            price: { currencyCode: 'USD', units: pack.units, nanos: 990000000 } }] }] });
    }
    if (path.endsWith('/monetization_subscription_plans')) return Response.json(rows);
    if (path.endsWith('/monetization_credit_packages')) return Response.json(packs.map((p) =>
      ({ id: p.id, product_id: 'chronospark_' + p.id, credits: p.credits, bonus_credits: 0,
        currency_code: 'USD', price_micros: p.micros, is_active: true })));
    if (path.endsWith('/google-play-rtdn')) {
      assert.equal(init.method, 'POST');
      assert.equal(init.body, '{}');
      assert.equal(new Headers(init.headers).has('authorization'), false);
      return new Response('', { status: 401, headers: headers() });
    }
    if (path.endsWith('/google_play_rtdn_events')) {
      const at = new Date(Date.now() - (state.rtdnFresh ? 1000 : 2 * 86400000)).toISOString();
      return Response.json([{ package_name: 'com.ghostheart5.chronospark', event_type: 'test',
        state: 'processed', failure_code: null, received_at: at, processed_at: at }]);
    }
    throw new Error('Unexpected fixture request');
  };
  return { env, state, request, calls };
}

test('explicit public license profile completes every existing read-only backend, catalog and RTDN guard', async () => {
  const f = publicFixture();
  const result = await verifyInternalBillingBackend(f.env, f.request, publicTestProfile());
  assert.equal(result.verified, true);
  assert.equal(result.creditAdmissionQaEnabled, true);
  assert.equal(result.publicCreditCheckout, 'enabled-v1');
  assert.deepEqual(result.backendTestProfile, { ...publicTestProfile(),
    profileSha256: createHash('sha256').update(JSON.stringify(publicTestProfile())).digest('hex') });
  assert.equal(result.internalBillingCohortFingerprint, publicTestProfile().reviewedBillingCohortSha256);
  assert.equal(result.backendRepairGate.canonicalCreditAuthorityIntact, true);
  assert.equal(result.deployedGoogleCredentialMatched, true);
  assert.equal(result.rtdn.unauthenticatedDeliveryRejected, true);
  assert.ok(f.calls.length > 15);
});

test('public profile rejects response, reviewed cohort, credential and RTDN drift', async () => {
  for (const change of [{ receiptStatus: 401 }, { contract: 'old' }, { checkout: 'disabled-v1' },
    { qa: 'disabled-v1' }, { cohort: '0'.repeat(64) }, { google: '0'.repeat(64) }, { rtdnFresh: false }]) {
    const f = publicFixture(); Object.assign(f.state, change);
    await assert.rejects(verifyInternalBillingBackend(f.env, f.request, publicTestProfile()));
  }
  const f = publicFixture();
  await assert.rejects(verifyInternalBillingBackend(f.env, f.request,
    { ...publicTestProfile(), reviewedBillingCohortSha256: '0'.repeat(64) }), /Reviewed billing cohort fingerprint/);
});

test('billing cohort fingerprint is order-independent and rejects unsafe inputs', () => {
  assert.equal(internalBillingCohortFingerprint(`${billingDigest},${'b'.repeat(64)}`),
    internalBillingCohortFingerprint(`${'b'.repeat(64)},${billingDigest}`));
  for (const bad of ['', 'A'.repeat(64), `${billingDigest},${billingDigest}`, 'not-a-digest']) {
    assert.throws(() => internalBillingCohortFingerprint(bad));
  }
});

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

test('credit pack gate rejects price, quantity, availability and backend drift', () => {
  const packs = [{id:'credits_100', credits:100, units:'2', micros:2990000}, {id:'credits_300',credits:300,units:'7',micros:7990000}];
  const products = packs.map((p) => ({packageName:'com.ghostheart5.chronospark',productId:`chronospark_${p.id}`,
    purchaseOptions:[{state:'ACTIVE',buyOption:{legacyCompatible:true,multiQuantityEnabled:false},
      regionalPricingAndAvailabilityConfigs:[{regionCode:'US',availability:'AVAILABLE',price:{currencyCode:'USD',units:p.units,nanos:990000000}}]}]}));
  const rows = packs.map((p) => ({id:p.id, product_id:`chronospark_${p.id}`,credits:p.credits,bonus_credits:0,
    price_micros:p.micros,currency_code:'USD',is_active:true}));
  assert.doesNotThrow(() => verifyCreditPackCatalog(products, rows));
  for (const mutate of [
    (p) => p[0].purchaseOptions[0].buyOption.multiQuantityEnabled=true,
    (p) => p[0].purchaseOptions[0].buyOption.legacyCompatible=false,
    (p) => p[0].purchaseOptions[0].state='DRAFT',
    (p) => p[0].purchaseOptions[0].regionalPricingAndAvailabilityConfigs[0].price.units='1',
    (p) => p[0].purchaseOptions[0].regionalPricingAndAvailabilityConfigs[0].regionCode='CA',
    (p) => p[0].purchaseOptions[0].newRegionsConfig={availability:'AVAILABLE'},
    (_,r) => r[0].credits=200,
  ]) {
    const p=structuredClone(products), r=structuredClone(rows);
    mutate(p,r);
    assert.throws(() => verifyCreditPackCatalog(p,r));
  }
});

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
  }), /does not keep public credit checkout closed/);
  assert.equal(calls, 1);
});

test('internal candidate preflight rejects a verifier with public checkout open', async () => {
  let calls = 0;
  await assert.rejects(verifyInternalBillingBackend({
    SUPABASE_PROJECT_REF: 'a'.repeat(20),
    CHRONOSPARK_SUPABASE_URL: `https://${'a'.repeat(20)}.supabase.co`,
    CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT: `https://${'a'.repeat(20)}.supabase.co/functions/v1/verify-receipt`,
    SUPABASE_SECRET_KEY: 'synthetic',
  }, async () => {
    calls++;
    return new Response('', { status: 405, headers: {
      'x-chronospark-contract': 'verify-receipt-v2',
      'x-chronospark-public-credit-checkout': 'enabled-v1',
    } });
  }), /does not keep public credit checkout closed/);
  assert.equal(calls, 1);
});

test('license-QA candidate needs a matching deployed admission policy before credentials', async () => {
  for (const marker of [undefined, 'disabled-v1']) {
    let calls = 0;
    await assert.rejects(verifyInternalBillingBackend({
      SUPABASE_PROJECT_REF: 'a'.repeat(20),
      CHRONOSPARK_SUPABASE_URL: `https://${'a'.repeat(20)}.supabase.co`,
      CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT: `https://${'a'.repeat(20)}.supabase.co/functions/v1/verify-receipt`,
      SUPABASE_SECRET_KEY: 'synthetic',
      CANDIDATE_CREDIT_ADMISSION_QA: 'true',
    }, async () => {
      calls++;
      return new Response('', { status: 405, headers: {
        'x-chronospark-contract': 'verify-receipt-v2',
        'x-chronospark-public-credit-checkout': 'disabled-v1',
        ...(marker ? { 'x-chronospark-credit-admission-qa': marker } : {}),
      } });
    }), /license-QA admission policy mismatch/);
    assert.equal(calls, 1);
  }
});

test('private credit admission backend requires its migration and active JWT-matched functions', async () => {
  const env = { SUPABASE_PROJECT_REF: 'a'.repeat(20), SUPABASE_ACCESS_TOKEN: 'synthetic' };
  const good = {
    '/database/migrations': [{ version: '20260924030236' }],
    '/functions': [
      { slug: 'verify-receipt', status: 'ACTIVE', verify_jwt: true, version: 42 },
      { slug: 'google-play-rtdn', status: 'ACTIVE', verify_jwt: false, version: 43 },
    ],
  };
  const request = (state) => async (url, init) => {
    assert.equal(init.headers.Authorization, 'Bearer synthetic');
    assert.equal(init.redirect, 'error');
    return Response.json(state[new URL(url).pathname.replace(`/v1/projects/${env.SUPABASE_PROJECT_REF}`, '')] ?? []);
  };
  assert.deepEqual(await verifyCreditAdmissionBackend(env, request(good)), {
    migrationVersion: '20260924030236',
    functionVersions: { 'verify-receipt': 42, 'google-play-rtdn': 43 },
  });
  for (const state of [
    { ...good, '/database/migrations': [] },
    { ...good, '/database/migrations': [good['/database/migrations'][0], good['/database/migrations'][0]] },
    { ...good, '/functions': [{ ...good['/functions'][0], verify_jwt: false }, good['/functions'][1]] },
    { ...good, '/functions': [good['/functions'][0], { ...good['/functions'][1], version: 0 }] },
  ]) {
    await assert.rejects(verifyCreditAdmissionBackend(env, request(state)));
  }
});

test('billing preflight cannot succeed without the deployed repair gate even with a current receipt marker', async () => {
  let calls = 0;
  await assert.rejects(verifyInternalBillingBackend({
    SUPABASE_PROJECT_REF: 'a'.repeat(20),
    CHRONOSPARK_SUPABASE_URL: `https://${'a'.repeat(20)}.supabase.co`,
    CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT: `https://${'a'.repeat(20)}.supabase.co/functions/v1/verify-receipt`,
    SUPABASE_SECRET_KEY: 'synthetic',
    CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS: billingDigest,
  }, async () => {
    calls++;
    return new Response('', { status: 405, headers: {
      'x-chronospark-contract': 'verify-receipt-v2', 'x-chronospark-public-credit-checkout': 'disabled-v1',
      'x-chronospark-internal-billing-cohort-sha256': internalBillingCohortFingerprint(billingDigest),
    } });
  }), /Missing SUPABASE_ACCESS_TOKEN/);
  assert.equal(calls, 1);
});

test('candidate preflight rejects a missing or mismatched deployed billing cohort before credentials', async () => {
  for (const hosted of [undefined, '0'.repeat(64)]) {
    let calls = 0;
    await assert.rejects(verifyInternalBillingBackend({
      SUPABASE_PROJECT_REF: 'a'.repeat(20),
      CHRONOSPARK_SUPABASE_URL: `https://${'a'.repeat(20)}.supabase.co`,
      CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT: `https://${'a'.repeat(20)}.supabase.co/functions/v1/verify-receipt`,
      SUPABASE_SECRET_KEY: 'synthetic',
      CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS: billingDigest,
    }, async () => {
      calls++;
      return new Response('', { status: 405, headers: {
        'x-chronospark-contract': 'verify-receipt-v2',
        'x-chronospark-public-credit-checkout': 'disabled-v1',
        ...(hosted ? { 'x-chronospark-internal-billing-cohort-sha256': hosted } : {}),
      } });
    }), /billing cohort does not match/);
    assert.equal(calls, 1);
  }
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
