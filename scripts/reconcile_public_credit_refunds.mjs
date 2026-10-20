// A scheduled caller for the reviewed refund worker, disabled by default.
// Never retries an ambiguous POST or logs provider/customer response fields.
import { pathToFileURL } from 'node:url';

const PROJECT_URL = 'https://qpwhuckyirnqtmvhpede.supabase.co';
const ENDPOINT = `${PROJECT_URL}/functions/v1/public-credit-refund-reconcile`;
const COUNTS = ['scanned', 'refunded', 'requested', 'pending', 'manualReview', 'retryLater'];

export function parseRefundReconciliationCounts(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    throw new Error('Invalid refund reconciliation response');
  }
  const counts = {};
  for (const name of COUNTS) {
    if (!Number.isSafeInteger(body[name]) || body[name] < 0 || body[name] > 5) {
      throw new Error('Invalid refund reconciliation count');
    }
    counts[name] = body[name];
  }
  if (COUNTS.slice(1).reduce((sum, name) => sum + counts[name], 0) !== counts.scanned) {
    throw new Error('Inconsistent refund reconciliation counts');
  }
  return counts;
}

export async function runPublicCreditRefundReconciliation(env = process.env, request = fetch) {
  if (env.AXIOMARA_PUBLIC_CREDIT_REFUNDS_ENABLED !== 'true' ||
      env.CHRONOSPARK_SUPABASE_URL !== PROJECT_URL ||
      typeof env.PUBLIC_CREDIT_REFUND_RECONCILE_SECRET !== 'string' ||
      !env.PUBLIC_CREDIT_REFUND_RECONCILE_SECRET.trim()) {
    throw new Error('Refund reconciliation is disabled or not configured');
  }
  // No retry: the server records a one-time claim before contacting Google.
  // A later scheduled invocation performs provider readback of that claim.
  const response = await request(ENDPOINT, {
    method: 'POST',
    headers: {
      'x-axiomara-refund-reconcile-secret': env.PUBLIC_CREDIT_REFUND_RECONCILE_SECRET,
      'Content-Type': 'application/json',
    },
    body: '{}',
    redirect: 'error',
    signal: AbortSignal.timeout(300000),
  });
  if (!response.ok) {
    await response.body?.cancel();
    throw new Error(`Refund reconciliation failed (${response.status})`);
  }
  const counts = parseRefundReconciliationCounts(await response.json());
  return {
    ...counts,
    requiresAttention: counts.manualReview > 0 || counts.retryLater > 0,
  };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const result = await runPublicCreditRefundReconciliation();
    console.log(JSON.stringify(result));
    if (result.requiresAttention) process.exitCode = 1;
  } catch {
    console.error('Public credit refund reconciliation failed; inspect the restricted worker and provider readback.');
    process.exitCode = 1;
  }
}
