// Read-only aggregate monitor for verified paid orders needing resolution.
// Never fetches raw tokens, order IDs, customer IDs, or wallet rows.
import { pathToFileURL } from 'node:url';

const PROJECT = 'qpwhuckyirnqtmvhpede';
const URL = `https://${PROJECT}.supabase.co/rest/v1/rpc/public_credit_checkout_resolution_health`;

export function classifyPublicCreditResolutionHealth(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('Invalid credit-resolution health response');
  }
  const fields = ['awaiting', 'awaitingOverOneHour', 'awaitingOverOneDay', 'refunded', 'fulfilled'];
  for (const key of fields) {
    if (!Number.isSafeInteger(value[key]) || value[key] < 0) {
      throw new Error('Invalid credit-resolution health count');
    }
  }
  if (value.awaitingOverOneDay > value.awaitingOverOneHour ||
      value.awaitingOverOneHour > value.awaiting) {
    throw new Error('Inconsistent credit-resolution health counts');
  }
  const oldest = value.oldestAwaitingAt;
  if (value.awaiting === 0 ? oldest !== null :
      typeof oldest !== 'string' || !Number.isFinite(Date.parse(oldest))) {
    throw new Error('Invalid oldest credit-resolution timestamp');
  }
  return {
    status: value.awaitingOverOneDay > 0 ? 'critical' :
      value.awaitingOverOneHour > 0 ? 'action_required' :
      value.awaiting > 0 ? 'watch' : 'clear',
    awaiting: value.awaiting,
    awaitingOverOneHour: value.awaitingOverOneHour,
    awaitingOverOneDay: value.awaitingOverOneDay,
    oldestAwaitingAt: oldest,
    refunded: value.refunded,
    fulfilled: value.fulfilled,
  };
}

export async function readPublicCreditResolutionHealth(env = process.env, request = fetch) {
  if (env.SUPABASE_PROJECT_REF !== PROJECT ||
      env.CHRONOSPARK_SUPABASE_URL !== `https://${PROJECT}.supabase.co` ||
      typeof env.SUPABASE_SECRET_KEY !== 'string' || !env.SUPABASE_SECRET_KEY.trim()) {
    throw new Error('Credit-resolution monitor project or credential is unavailable');
  }
  const response = await request(URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.SUPABASE_SECRET_KEY}`,
      apikey: env.SUPABASE_SECRET_KEY,
      'Content-Type': 'application/json',
    },
    body: '{}',
    redirect: 'error',
    signal: AbortSignal.timeout(20000),
  });
  if (!response.ok) {
    await response.body?.cancel();
    throw new Error(`Credit-resolution health read failed (${response.status})`);
  }
  return classifyPublicCreditResolutionHealth(await response.json());
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const health = await readPublicCreditResolutionHealth();
    console.log(JSON.stringify(health));
    if (health.status === 'action_required' || health.status === 'critical') {
      process.exitCode = 2;
    }
  } catch {
    // A transport error may contain a URL or headers; never print credentials.
    console.error('Credit-resolution health read failed');
    process.exitCode = 1;
  }
}
