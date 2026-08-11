import { createSign } from 'node:crypto';

const requiredSubscriptions = new Set([
  'chronospark_premium_monthly',
  'chronospark_premium_annual',
]);
const requiredOneTimeProducts = new Set([
  'chronospark_lifetime',
  'chronospark_credits_100',
  'chronospark_credits_500',
  'chronospark_credits_1200',
  'chronospark_credits_3000',
]);

function requiredEnv(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required`);
  return value;
}

function base64Url(value) {
  return Buffer.from(value).toString('base64url');
}

async function googleAccessToken(serviceAccount, scope) {
  const now = Math.floor(Date.now() / 1000);
  const encodedHeader = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const encodedClaims = base64Url(JSON.stringify({
    iss: serviceAccount.client_email,
    scope,
    aud: serviceAccount.token_uri ?? 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${encodedHeader}.${encodedClaims}`;
  const signer = createSign('RSA-SHA256');
  signer.update(unsigned);
  signer.end();
  const assertion = `${unsigned}.${signer.sign(serviceAccount.private_key, 'base64url')}`;
  const response = await fetch(serviceAccount.token_uri ?? 'https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth2:grant-type:jwt-bearer',
      assertion,
    }),
    signal: AbortSignal.timeout(20_000),
  });
  const body = await response.json();
  if (!response.ok || typeof body.access_token !== 'string') {
    throw new Error(`Google service-account token exchange failed (${response.status})`);
  }
  return body.access_token;
}

async function fetchJson(url, init = {}) {
  const response = await fetch(url, { ...init, signal: AbortSignal.timeout(20_000) });
  const text = await response.text();
  let body = null;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = text;
  }
  if (!response.ok) {
    throw new Error(`${url} returned ${response.status}: ${String(text).slice(0, 180)}`);
  }
  return body;
}

async function assertStatus(url, expected, init = {}) {
  const response = await fetch(url, { ...init, signal: AbortSignal.timeout(20_000) });
  await response.body?.cancel();
  if (response.status !== expected) {
    throw new Error(`${url} returned ${response.status}; expected ${expected}`);
  }
}

async function assertContract(url, expectedContract) {
  const response = await fetch(url, {
    headers: serviceHeaders,
    signal: AbortSignal.timeout(20_000),
  });
  await response.body?.cancel();
  if (response.status !== 405) {
    throw new Error(`${url} contract probe returned ${response.status}; expected 405`);
  }
  if (response.headers.get('x-chronospark-contract') !== expectedContract) {
    throw new Error(`${url} is not deployed with contract ${expectedContract}`);
  }
}

function assertExactIds(actual, expected, label) {
  const missing = [...expected].filter((id) => !actual.has(id));
  const unexpected = [...actual].filter((id) => !expected.has(id));
  if (missing.length || unexpected.length) {
    throw new Error(
      `${label} mismatch; missing=[${missing.join(', ')}], unexpected=[${unexpected.join(', ')}]`,
    );
  }
}

const supabaseUrl = requiredEnv('CHRONOSPARK_SUPABASE_URL').replace(/\/$/, '');
const secretKey = requiredEnv('SUPABASE_SECRET_KEY');
const packageName = requiredEnv('ANDROID_PACKAGE_NAME');
if (packageName !== 'com.ghostheart5.chronospark') {
  throw new Error(`Unexpected Android package: ${packageName}`);
}
const serviceAccount = JSON.parse(requiredEnv('GOOGLE_SERVICE_ACCOUNT_JSON'));
const rtdnSubscription = requiredEnv('RTDN_PUBSUB_SUBSCRIPTION');
const rtdnAudience = requiredEnv('RTDN_AUDIENCE');
const rtdnServiceAccountEmail = requiredEnv('RTDN_SERVICE_ACCOUNT_EMAIL');
const reconcileSecret = requiredEnv('ACCOUNT_DELETE_RECONCILE_SECRET');
if (!serviceAccount.client_email || !serviceAccount.private_key) {
  throw new Error('GOOGLE_SERVICE_ACCOUNT_JSON is not a service-account credential');
}

const serviceHeaders = { apikey: secretKey, Authorization: `Bearer ${secretKey}` };
const plans = await fetchJson(
  `${supabaseUrl}/rest/v1/monetization_subscription_plans?select=product_id,is_active&is_active=eq.true`,
  { headers: serviceHeaders },
);
const packages = await fetchJson(
  `${supabaseUrl}/rest/v1/monetization_credit_packages?select=product_id,is_active&is_active=eq.true`,
  { headers: serviceHeaders },
);
assertExactIds(new Set(plans.map((row) => row.product_id)), new Set([
  ...requiredSubscriptions,
  'chronospark_lifetime',
]), 'Supabase subscription catalog');
assertExactIds(
  new Set(packages.map((row) => row.product_id)),
  new Set([...requiredOneTimeProducts].filter((id) => id !== 'chronospark_lifetime')),
  'Supabase credit catalog',
);

const functionsUrl = `${supabaseUrl}/functions/v1`;
const jsonPost = {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', Origin: 'https://chronospark.app' },
  body: '{}',
};
await assertStatus(`${functionsUrl}/ai-proxy`, 401, jsonPost);
await assertStatus(`${functionsUrl}/monetization-verify`, 401, jsonPost);
await assertStatus(`${functionsUrl}/account-delete-reconcile`, 401, jsonPost);
await assertStatus(`${functionsUrl}/google-play-rtdn`, 401, jsonPost);
await assertStatus(`${functionsUrl}/delete-account`, 410, jsonPost);
await assertStatus(`${functionsUrl}/verify-receipt`, 410, jsonPost);
await assertStatus(`${functionsUrl}/webhook-ingest`, 410, jsonPost);
await assertContract(`${functionsUrl}/ai-proxy`, 'ai-proxy-v2');
await assertContract(`${functionsUrl}/monetization-verify`, 'monetization-v2');
await assertContract(`${functionsUrl}/account-delete`, 'account-delete-v2');
await assertContract(`${functionsUrl}/google-play-rtdn`, 'google-play-rtdn-v1');
await assertContract(
  `${functionsUrl}/account-delete-reconcile`,
  'account-delete-reconcile-v1',
);
await fetchJson(`${functionsUrl}/account-delete-reconcile`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'x-chronospark-reconcile-secret': reconcileSecret,
  },
  body: '{}',
});

const accessToken = await googleAccessToken(
  serviceAccount,
  'https://www.googleapis.com/auth/androidpublisher',
);
const playHeaders = { Authorization: `Bearer ${accessToken}` };
const packagePath = encodeURIComponent(packageName);
const subscriptions = await fetchJson(
  `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packagePath}/subscriptions?pageSize=1000`,
  { headers: playHeaders },
);
const subscriptionRows = subscriptions.subscriptions ?? [];
assertExactIds(
  new Set(subscriptionRows.map((item) => item.productId)),
  requiredSubscriptions,
  'Google Play subscription catalog',
);
for (const productId of requiredSubscriptions) {
  const product = subscriptionRows.find((item) => item.productId === productId);
  const activePlans = (product?.basePlans ?? []).filter((plan) => plan.state === 'ACTIVE');
  if (!activePlans.length) throw new Error(`${productId} has no ACTIVE base plan`);
}

let oneTimeRows;
try {
  const modern = await fetchJson(
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packagePath}/oneTimeProducts?pageSize=1000`,
    { headers: playHeaders },
  );
  oneTimeRows = modern.oneTimeProducts ?? [];
} catch {
  const legacy = await fetchJson(
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packagePath}/inappproducts?maxResults=100`,
    { headers: playHeaders },
  );
  oneTimeRows = legacy.inappproduct ?? [];
}
assertExactIds(
  new Set(oneTimeRows.map((item) => item.productId ?? item.sku)),
  requiredOneTimeProducts,
  'Google Play one-time product catalog',
);
for (const productId of requiredOneTimeProducts) {
  const product = oneTimeRows.find((item) => (item.productId ?? item.sku) === productId);
  const active = product?.status === 'active' || product?.state === 'ACTIVE' ||
    (product?.purchaseOptions ?? []).some((option) => option.state === 'ACTIVE');
  if (!active) throw new Error(`${productId} is not active in Google Play`);
}

if (!/^projects\/[a-z0-9-]+\/subscriptions\/[A-Za-z0-9._~-]+$/.test(rtdnSubscription)) {
  throw new Error('RTDN_PUBSUB_SUBSCRIPTION must be a full Pub/Sub subscription resource name');
}
const pubsubToken = await googleAccessToken(
  serviceAccount,
  'https://www.googleapis.com/auth/cloud-platform',
);
const pubsub = await fetchJson(
  `https://pubsub.googleapis.com/v1/${rtdnSubscription}`,
  { headers: { Authorization: `Bearer ${pubsubToken}` } },
);
const expectedPushEndpoint = `${functionsUrl}/google-play-rtdn`;
if (pubsub.pushConfig?.pushEndpoint !== expectedPushEndpoint) {
  throw new Error(`RTDN push endpoint does not match ${expectedPushEndpoint}`);
}
if (pubsub.pushConfig?.oidcToken?.audience !== rtdnAudience) {
  throw new Error('RTDN Pub/Sub OIDC audience does not match RTDN_AUDIENCE');
}
if (pubsub.pushConfig?.oidcToken?.serviceAccountEmail !== rtdnServiceAccountEmail) {
  throw new Error('RTDN Pub/Sub OIDC service account does not match RTDN_SERVICE_ACCOUNT_EMAIL');
}

console.log(JSON.stringify({
  verified: true,
  packageName,
  supabasePlans: plans.length,
  supabaseCreditPackages: packages.length,
  playSubscriptions: subscriptionRows.length,
  playOneTimeProducts: oneTimeRows.length,
  rtdnSubscription,
}));
