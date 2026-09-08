// Read-only preflight for a license-test candidate; no purchase or release API.
import { createHash, createSign } from 'node:crypto';
import { pathToFileURL } from 'node:url';

const PACKAGE = 'com.ghostheart5.chronospark';
const PLANS = [
  { id: 'premium_monthly', product: 'chronospark_premium_monthly', base: 'monthly', period: 'P1M', micros: 7990000, credits: 300 },
  { id: 'premium_yearly', product: 'chronospark_premium_annual', base: 'annual', period: 'P1Y', micros: 69990000, credits: 300 },
];
const CREDIT_PACKS = [
  { id: 'credits_100', product: 'chronospark_credits_100', credits: 100, micros: 2990000 },
  { id: 'credits_300', product: 'chronospark_credits_300', credits: 300, micros: 7990000 },
];
class PreflightError extends Error {}
function require(condition, message) {
  if (!condition) throw new PreflightError(message);
}

export function googleCredentialFingerprint(account) {
  require(typeof account?.client_email === 'string' && !!account.client_email &&
    typeof account.private_key === 'string' && !!account.private_key, 'Invalid Google service-account configuration');
  const key = account.private_key.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, '');
  require(!!key, 'Invalid Google service-account key');
  return createHash('sha256').update(JSON.stringify([account.client_email, key])).digest('hex');
}

export function verifyCatalog(products, databasePlans) {
  require(Array.isArray(products) && products.length === 2, 'Expected exactly two Play subscriptions');
  require(Array.isArray(databasePlans) && databasePlans.length === 2, 'Expected two backend subscription plans');
  for (const expected of PLANS) {
    const product = products.find((p) => p.productId === expected.product);
    require(product?.packageName === PACKAGE, 'Play package or product mismatch');
    const active = (product.basePlans ?? []).filter((p) => p.state === 'ACTIVE');
    require(active.filter((p) => p.basePlanId === expected.base).length === 1, 'Expected approved renewing base plan');
    const extras = active.filter((p) => p.basePlanId !== expected.base);
    require(extras.length <= 1 && extras.every((p) => expected.base === 'monthly' &&
      p.basePlanId === 'monthly-prepaid-test' && p.prepaidBasePlanType?.billingPeriodDuration === 'P1M' &&
      !p.autoRenewingBasePlanType), 'Unexpected active base plan');
    for (const base of active) {
      if (base.basePlanId === expected.base) {
        require(base.autoRenewingBasePlanType?.billingPeriodDuration === expected.period, 'Billing period mismatch');
      }
      const available = (base.regionalConfigs ?? []).filter((r) => r.newSubscriberAvailability === true);
      require(available.length === 1 && available[0].regionCode === 'US', 'Test catalog must be available only in the US');
      require(base.otherRegionsConfig?.newSubscriberAvailability !== true, 'Future-region availability is not approved');
      const price = available[0].price;
      const nanos = Number(price?.nanos ?? 0);
      const micros = Number(price?.units) * 1000000 + nanos / 1000;
      require(price?.currencyCode === 'USD' && Number.isSafeInteger(micros) && micros === expected.micros, 'Approved catalog price mismatch');
    }
    const row = databasePlans.find((p) => p.id === expected.id);
    require(row?.product_id === expected.product && row.currency_code === 'USD' &&
      row.price_micros === expected.micros && row.credits_per_period === expected.credits &&
      row.is_active === true, 'Backend catalog does not match the approved plan');
  }
}

export function verifyRtdnTestDelivery(events, now = Date.now()) {
  require(Array.isArray(events) && events.length === 1, 'Send a fresh Google Play RTDN test notification before building');
  const event = events[0];
  const received = Date.parse(event.received_at);
  const processed = Date.parse(event.processed_at);
  require(event.package_name === PACKAGE && event.event_type === 'test' &&
    event.state === 'processed' && event.failure_code === null,
  'Latest Google Play RTDN test did not process successfully');
  require(Number.isFinite(received) && Number.isFinite(processed) &&
    received > now - 24 * 60 * 60 * 1000 && received <= processed && processed <= now,
  'Google Play RTDN test evidence must be processed within the last 24 hours');
  return { receivedAt: new Date(received).toISOString(), processedAt: new Date(processed).toISOString() };
}

export function verifyCreditPackCatalog(products, rows) {
  require(Array.isArray(products) && products.length === 2 && Array.isArray(rows) && rows.length === 2,
    'Expected exactly two active credit packs');
  for (const expected of CREDIT_PACKS) {
    const product = products.find((p) => p.productId === expected.product);
    require(product?.packageName === PACKAGE, 'Credit pack package mismatch');
    const active = (product.purchaseOptions ?? []).filter((p) => p.state === 'ACTIVE');
    require(active.length === 1 && active[0].buyOption?.legacyCompatible === true &&
      active[0].buyOption?.multiQuantityEnabled !== true && !active[0].rentOption,
    'Credit pack must have one compatible single-quantity buy option');
    const available = (active[0].regionalPricingAndAvailabilityConfigs ?? []).filter((r) => r.availability === 'AVAILABLE');
    require(available.length === 1 && available[0].regionCode === 'US' &&
      active[0].newRegionsConfig?.availability !== 'AVAILABLE', 'Credit packs must remain US-only');
    const price = available[0].price;
    require(price?.currencyCode === 'USD' && Number(price.units) * 1000000 + Number(price.nanos ?? 0) / 1000 === expected.micros,
      'Credit pack price mismatch');
    const row = rows.find((r) => r.id === expected.id);
    require(row?.product_id === expected.product && row.credits === expected.credits && row.bonus_credits === 0 &&
      row.currency_code === 'USD' && row.price_micros === expected.micros && row.is_active === true,
    'Backend credit pack mismatch');
  }
}

export async function verifyInternalBillingBackend(env = process.env, request = fetch) {
  function setting(name) {
    const value = env[name]?.trim();
    require(!!value, `Missing ${name}`);
    return value;
  }
  const project = setting('SUPABASE_PROJECT_REF');
  const root = setting('CHRONOSPARK_SUPABASE_URL').replace(/\/$/, '');
  require(/^[a-z0-9]{20}$/.test(project) && root === `https://${project}.supabase.co`, 'Backend project identity mismatch');
  const endpoint = `${root}/functions/v1/verify-receipt`;
  require(setting('CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT') === endpoint, 'Receipt endpoint identity mismatch');
  const secret = setting('SUPABASE_SECRET_KEY');
  const headers = { apikey: secret, Authorization: `Bearer ${secret}` };
  async function response(url, init = {}) {
    return await request(url, { ...init, redirect: 'error', signal: AbortSignal.timeout(20000) });
  }
  async function json(url, init = {}) {
    const result = await response(url, init);
    if (!result.ok) {
      const body = await result.json().catch(() => null);
      const reason = body?.error?.errors?.[0]?.reason ?? body?.error?.status;
      const safeReason = typeof reason === 'string' && /^[A-Za-z0-9_.-]{1,80}$/.test(reason) ? `: ${reason}` : '';
      throw new PreflightError(`${new URL(url).hostname} preflight failed (${result.status}${safeReason})`);
    }
    return await result.json();
  }
  const guard = await response(endpoint, { headers });
  await guard.body?.cancel();
  require(guard.status === 405 && guard.headers.get('x-chronospark-contract') === 'verify-receipt-v2' &&
    guard.headers.get('x-chronospark-test-purchase-guard') === 'v1', 'Deployed receipt verifier lacks the license-test guard');

  const databasePlans = await json(`${root}/rest/v1/monetization_subscription_plans?plan_type=eq.subscription&select=id,product_id,currency_code,price_micros,credits_per_period,is_active`, { headers });
  const account = JSON.parse(setting('GOOGLE_SERVICE_ACCOUNT_JSON'));
  require(account.token_uri === 'https://oauth2.googleapis.com/token' &&
    typeof account.client_email === 'string' && typeof account.private_key === 'string', 'Invalid Google service-account configuration');
  const credentialFingerprint = googleCredentialFingerprint(account);
  require(guard.headers.get('x-chronospark-google-credential-sha256') === credentialFingerprint,
    'Hosted preflight credential does not match the deployed receipt verifier');
  async function googleToken(scope) {
    const now = Math.floor(Date.now() / 1000);
    const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
    const unsigned = `${encode({ alg: 'RS256', typ: 'JWT' })}.${encode({
      iss: account.client_email, scope, aud: account.token_uri, iat: now, exp: now + 3600,
    })}`;
    const signer = createSign('RSA-SHA256');
    signer.update(unsigned);
    signer.end();
    const assertion = `${unsigned}.${signer.sign(account.private_key, 'base64url')}`;
    const token = await json(account.token_uri, {
      method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
    });
    require(typeof token.access_token === 'string', 'Google token exchange failed');
    return token.access_token;
  }
  const publisher = await googleToken('https://www.googleapis.com/auth/androidpublisher');
  const serviceAccountIdentitySha256 = createHash('sha256').update(account.client_email).digest('hex');
  const products = [];
  for (const plan of PLANS) {
    try {
      products.push(await json(`https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE}/subscriptions/${plan.product}`, {
        headers: { Authorization: `Bearer ${publisher}` },
      }));
    } catch (error) {
      if (error instanceof PreflightError) {
        throw new PreflightError(`${error.message}; service-account identity SHA256 ${serviceAccountIdentitySha256}`);
      }
      throw error;
    }
  }
  verifyCatalog(products, databasePlans);
  const creditProducts = [];
  for (const pack of CREDIT_PACKS) {
    creditProducts.push(await json(`https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE}/onetimeproducts/${pack.product}`, {
      headers: { Authorization: `Bearer ${publisher}` },
    }));
  }
  const creditRows = await json(`${root}/rest/v1/monetization_credit_packages?is_active=eq.true&select=id,product_id,credits,bonus_credits,currency_code,price_micros,is_active`, {headers});
  verifyCreditPackCatalog(creditProducts, creditRows);
  // Billing credentials do not need Pub/Sub infrastructure access. Verify the
  // authenticated delivery path instead, using service-controlled event evidence.
  // This empty unauthenticated probe must fail before any event can be written.
  const unauthenticated = await response(`${root}/functions/v1/google-play-rtdn`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}',
  });
  await unauthenticated.body?.cancel();
  require(unauthenticated.status === 401, 'RTDN endpoint must reject unauthenticated delivery');
  const events = await json(`${root}/rest/v1/google_play_rtdn_events?package_name=eq.${PACKAGE}&event_type=eq.test&order=received_at.desc&limit=1&select=package_name,event_type,state,failure_code,received_at,processed_at`, { headers });
  const testDelivery = verifyRtdnTestDelivery(events);
  return { verified: true, project, packageName: PACKAGE, licenseTestGuard: 'v1',
    catalog: PLANS.map(({ product, base, period, micros }) => ({ product, base, period, currency: 'USD', priceMicros: micros })),
    creditPacks: CREDIT_PACKS.map(({product, credits, micros}) => ({product, credits, currency: 'USD', priceMicros: micros})),
    serviceAccountIdentitySha256,
    googleCredentialFingerprint: credentialFingerprint, deployedGoogleCredentialMatched: true,
    rtdn: { unauthenticatedDeliveryRejected: true, testDelivery },
    verifiedAt: new Date().toISOString(),
    boundary: 'Configuration and authenticated test notification only; device purchases and subscription lifecycle remain to be tested.' };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    console.log(JSON.stringify(await verifyInternalBillingBackend()));
  } catch (error) {
    // Never serialize HTTP request objects or credential-bearing provider errors.
    console.error(error instanceof PreflightError ? error.message : 'Billing preflight failed: invalid response, credentials or network error');
    process.exitCode = 1;
  }
}
