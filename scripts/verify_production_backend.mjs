import { createSign } from 'node:crypto';
import { readFile } from 'node:fs/promises';

const expectedSubscriptions = new Set([
  'chronospark_premium_monthly',
  'chronospark_premium_annual',
]);

function requiredEnv(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required`);
  return value;
}

function base64Url(value) {
  return Buffer.from(value).toString('base64url');
}

function normalizedFingerprint(value) {
  const compact = value.replace(/[^0-9a-f]/gi, '').toUpperCase();
  if (!/^[0-9A-F]{64}$/.test(compact)) {
    throw new Error('CHRONOSPARK_ANDROID_SHA256_CERT is not a SHA-256 certificate fingerprint');
  }
  return compact.match(/.{2}/g).join(':');
}

async function fetchResponse(url, init = {}) {
  return await fetch(url, {
    ...init,
    signal: AbortSignal.timeout(20_000),
  });
}

async function fetchJson(url, init = {}) {
  const response = await fetchResponse(url, init);
  const text = await response.text();
  let body;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    throw new Error(`${url} returned non-JSON content`);
  }
  if (!response.ok) {
    throw new Error(`${url} returned ${response.status}`);
  }
  return body;
}

async function assertFunctionContract(url, expectedContract) {
  const response = await fetchResponse(url, {
    method: 'GET',
    headers: serviceHeaders,
  });
  await response.body?.cancel();
  if (response.status !== 405) {
    throw new Error(`${url} returned ${response.status}; expected method guard 405`);
  }
  if (expectedContract && response.headers.get('x-chronospark-contract') !== expectedContract) {
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

async function googleAccessToken(serviceAccount, scope) {
  const now = Math.floor(Date.now() / 1000);
  const tokenUri = serviceAccount.token_uri ?? 'https://oauth2.googleapis.com/token';
  const encodedHeader = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const encodedClaims = base64Url(JSON.stringify({
    iss: serviceAccount.client_email,
    scope,
    aud: tokenUri,
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${encodedHeader}.${encodedClaims}`;
  const signer = createSign('RSA-SHA256');
  signer.update(unsigned);
  signer.end();
  const assertion = `${unsigned}.${signer.sign(serviceAccount.private_key, 'base64url')}`;
  const response = await fetchResponse(tokenUri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth2:grant-type:jwt-bearer',
      assertion,
    }),
  });
  const body = await response.json();
  if (!response.ok || typeof body.access_token !== 'string') {
    throw new Error(`Google service-account token exchange failed (${response.status})`);
  }
  return body.access_token;
}

const supabaseUrl = requiredEnv('CHRONOSPARK_SUPABASE_URL').replace(/\/$/, '');
const projectRef = requiredEnv('SUPABASE_PROJECT_REF');
const secretKey = requiredEnv('SUPABASE_SECRET_KEY');
const configuredAccountDeleteEndpoint = requiredEnv('CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT');
const packageName = requiredEnv('ANDROID_PACKAGE_NAME');
const expectedFingerprint = normalizedFingerprint(
  requiredEnv('CHRONOSPARK_ANDROID_SHA256_CERT'),
);
const rtdnSubscription = requiredEnv('RTDN_PUBSUB_SUBSCRIPTION');
const rtdnAudience = requiredEnv('RTDN_AUDIENCE');
const rtdnServiceAccountEmail = requiredEnv('RTDN_SERVICE_ACCOUNT_EMAIL');
const serviceAccount = JSON.parse(requiredEnv('GOOGLE_SERVICE_ACCOUNT_JSON'));

if (!/^[a-z0-9]{20}$/.test(projectRef)) {
  throw new Error('SUPABASE_PROJECT_REF has an unexpected format');
}
if (new URL(supabaseUrl).hostname !== `${projectRef}.supabase.co`) {
  throw new Error('CHRONOSPARK_SUPABASE_URL does not match SUPABASE_PROJECT_REF');
}
if (packageName !== 'com.ghostheart5.chronospark') {
  throw new Error(`Unexpected Android package: ${packageName}`);
}
if (!serviceAccount.client_email || !serviceAccount.private_key) {
  throw new Error('GOOGLE_SERVICE_ACCOUNT_JSON is not a service-account credential');
}
if (!/^projects\/[a-z0-9-]+\/subscriptions\/[A-Za-z0-9._~-]+$/.test(rtdnSubscription)) {
  throw new Error('RTDN_PUBSUB_SUBSCRIPTION must be a full Pub/Sub subscription resource name');
}

const functionsUrl = `${supabaseUrl}/functions/v1`;
const accountDeleteEndpoint = `${functionsUrl}/account-delete`;
if (configuredAccountDeleteEndpoint.replace(/\/$/, '') !== accountDeleteEndpoint) {
  throw new Error('CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT does not target the linked production project');
}
const serviceHeaders = {
  apikey: secretKey,
  Authorization: `Bearer ${secretKey}`,
};

await fetchJson(
  `${supabaseUrl}/rest/v1/account_deletion_requests?select=request_id&limit=1`,
  { headers: serviceHeaders },
);
await assertFunctionContract(`${functionsUrl}/ai-proxy`, 'ai-proxy-v2');
await assertFunctionContract(`${functionsUrl}/verify-receipt`, 'verify-receipt-v2');
await assertFunctionContract(accountDeleteEndpoint, 'account-delete-v2');
await assertFunctionContract(
  `${functionsUrl}/account-delete-reconcile`,
  'account-delete-reconcile-v1',
);
await assertFunctionContract(`${functionsUrl}/google-play-rtdn`, null);

const androidManifest = await readFile(
  new URL('../android/app/src/main/AndroidManifest.xml', import.meta.url),
  'utf8',
);
const declaresHttpsAppLinks =
  /android:scheme\s*=\s*["']https["']/.test(androidManifest) ||
  /android:autoVerify\s*=\s*["']true["']/.test(androidManifest);
if (declaresHttpsAppLinks) {
  throw new Error(
    'HTTPS App Links are declared but no reviewed Axiomara domain association is configured',
  );
}

const publisherToken = await googleAccessToken(
  serviceAccount,
  'https://www.googleapis.com/auth/androidpublisher',
);
const packagePath = encodeURIComponent(packageName);
const subscriptions = await fetchJson(
  `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packagePath}/subscriptions?pageSize=1000`,
  { headers: { Authorization: `Bearer ${publisherToken}` } },
);
const subscriptionRows = subscriptions.subscriptions ?? [];
assertExactIds(
  new Set(subscriptionRows.map((item) => item.productId)),
  expectedSubscriptions,
  'Google Play subscription catalog',
);
for (const productId of expectedSubscriptions) {
  const product = subscriptionRows.find((item) => item.productId === productId);
  const activePlans = (product?.basePlans ?? []).filter((plan) => plan.state === 'ACTIVE');
  if (!activePlans.length) throw new Error(`${productId} has no ACTIVE base plan`);
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
  commit: process.env.GITHUB_SHA ?? null,
  packageName,
  projectRef,
  playSubscriptions: subscriptionRows.length,
  httpsAppLinksDeclared: false,
  signingCertificateFingerprint: expectedFingerprint,
  rtdnSubscription,
}));
