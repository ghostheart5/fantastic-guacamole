// Manual, protected license-test invocation. This never changes enablement,
// deploys code, broadens a test target, or retries an uncertain refund request.
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { runPublicCreditRefundReconciliation } from './reconcile_public_credit_refunds.mjs';

const PROJECT = 'qpwhuckyirnqtmvhpede';
const REPOSITORY = 'ghostheart5/fantastic-guacamole';
const REF = 'refs/heads/fix/app-only-readiness-priority2-20260902';
const sha256 = (value) => createHash('sha256').update(value).digest('hex');
function require(value) {
  if (!value) throw new Error('License refund gate failed closed');
}

export function validateLicenseRefundGateContext(env, ci) {
  require(env.GITHUB_ACTIONS === 'true' && env.GITHUB_EVENT_NAME === 'workflow_dispatch' &&
    env.GITHUB_REPOSITORY === REPOSITORY && env.GITHUB_REF === REF &&
    env.LICENSE_REFUND_OPERATION === 'test-credit-refund');
  require(/^[a-f0-9]{40}$/.test(env.LICENSE_REFUND_SOURCE_SHA ?? '') &&
    env.LICENSE_REFUND_CHECKOUT_SHA === env.LICENSE_REFUND_SOURCE_SHA &&
    /^[1-9][0-9]*$/.test(env.LICENSE_REFUND_CI_RUN ?? '') &&
    /^[a-f0-9]{64}$/.test(env.LICENSE_REFUND_SCOPE_DIGEST ?? '') &&
    /^[a-f0-9]{64}$/.test(env.LICENSE_REFUND_WORKER_SHA256 ?? ''));
  require(ci && String(ci.id) === env.LICENSE_REFUND_CI_RUN &&
    ci.head_sha === env.LICENSE_REFUND_SOURCE_SHA && ci.repository?.full_name === REPOSITORY &&
    ci.path === '.github/workflows/ci.yml' && ci.event === 'workflow_dispatch' &&
    ci.status === 'completed' && ci.conclusion === 'success');
  require(env.CHRONOSPARK_SUPABASE_URL === `https://${PROJECT}.supabase.co` &&
    [undefined, '', 'false'].includes(env.AXIOMARA_PUBLIC_CREDIT_REFUNDS_ENABLED));
  for (const key of ['SUPABASE_ACCESS_TOKEN', 'PUBLIC_CREDIT_REFUND_RECONCILE_SECRET']) {
    require(typeof env[key] === 'string' && env[key].trim());
  }
}

export function validateLicenseRefundServer(env, secrets, functions) {
  require(Array.isArray(secrets) && Array.isArray(functions));
  require(secrets.every((item) => typeof item?.name === 'string' && typeof item.value === 'string') &&
    new Set(secrets.map((item) => item.name)).size === secrets.length);
  const values = new Map(secrets.map((item) => [item.name, item.value]));
  const matches = (name, expected) =>
    values.get(name) === expected || values.get(name) === sha256(expected);
  require(matches('PUBLIC_CREDIT_AUTO_REFUND_ENABLED', 'true') &&
    matches('PUBLIC_CREDIT_REFUND_TEST_ONLY', 'true'));
  const target = values.get('PUBLIC_CREDIT_REFUND_TEST_TOKEN_HASH');
  require(typeof target === 'string' && /^[a-f0-9]{64}$/.test(target) &&
    (target === env.LICENSE_REFUND_SCOPE_DIGEST || sha256(target) === env.LICENSE_REFUND_SCOPE_DIGEST));
  for (const name of ['CHRONOSPARK_PUBLIC_CREDIT_TOPUPS_ENABLED',
    'CHRONOSPARK_PUBLIC_BILLING_REVIEW_APPROVED',
    'CHRONOSPARK_PUBLIC_CREDIT_REFUND_READINESS_VERIFIED']) {
    require(!values.has(name) || matches(name, 'false'));
  }
  const worker = functions.filter((item) => item?.slug === 'public-credit-refund-reconcile');
  require(worker.length === 1 && worker[0].status === 'ACTIVE' && worker[0].verify_jwt === false &&
    worker[0].ezbr_sha256 === env.LICENSE_REFUND_WORKER_SHA256 &&
    Number.isSafeInteger(worker[0].version) && worker[0].version > 0);
  return worker[0].version;
}

export async function runLicenseRefundGate(env, ci, request = fetch) {
  validateLicenseRefundGateContext(env, ci);
  const read = async (resource) => {
    const response = await request(`https://api.supabase.com/v1/projects/${PROJECT}/${resource}`, {
      headers: { Authorization: `Bearer ${env.SUPABASE_ACCESS_TOKEN}` },
      redirect: 'error', signal: AbortSignal.timeout(30000),
    });
    require(response.ok);
    return await response.json();
  };
  const secrets = await read('secrets');
  const functions = await read('functions');
  const workerVersion = validateLicenseRefundServer(env, secrets, functions);
  const counts = await runPublicCreditRefundReconciliation({
    ...env,
    // This affirmative authorizes only the manual POST after the server-owned
    // test scope is checked. The scheduled repository variable must stay off.
    AXIOMARA_PUBLIC_CREDIT_REFUNDS_ENABLED: 'true',
  }, request);
  require(counts.scanned === 1);
  return { mode: 'license_test_only', workerVersion, ...counts };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const { readFileSync } = await import('node:fs');
    const ci = JSON.parse(readFileSync(process.argv[2], 'utf8'));
    const result = await runLicenseRefundGate(process.env, ci);
    console.log(JSON.stringify(result));
    if (result.requiresAttention) process.exitCode = 1;
  } catch {
    console.error('License refund gate failed; inspect restricted configuration and provider evidence. No automatic retry.');
    process.exitCode = 1;
  }
}
