import { randomBytes, randomUUID } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export const PROJECT = 'qpwhuckyirnqtmvhpede';
const BASE = `https://${PROJECT}.supabase.co`;
const uuid = /^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/;
function require(value, message) { if (!value) throw new Error(message); }

export function validateContext(env) {
  require(env.GITHUB_ACTIONS === 'true' && env.GITHUB_EVENT_NAME === 'workflow_dispatch' &&
    env.GITHUB_REPOSITORY === 'ghostheart5/fantastic-guacamole' &&
    env.GITHUB_ACTOR === 'ghostheart5' && env.GITHUB_REF === 'refs/heads/main',
  'Requires owner-dispatched protected production tooling');
  require(/^[1-9][0-9]*$/.test(env.GITHUB_RUN_ID ?? '') &&
    env.CHRONOSPARK_SUPABASE_URL?.replace(/\/$/, '') === BASE &&
    env.SUPABASE_PROJECT_REF === PROJECT && env.SUPABASE_SECRET_KEY &&
    env.CHRONOSPARK_SUPABASE_ANON_KEY && env.RUNNER_TEMP,
  'Exact production project and existing configured keys are required');
  require(/^[a-f0-9]{40}$/.test(env.ACCEPTANCE_SOURCE_SHA ?? ''),
    'Immutable reviewed backend source is required');
  return BASE;
}

export function validateManifest(manifest, runId) {
  require(manifest?.schemaVersion === 1 && manifest.runId === runId && uuid.test(manifest.nonce) &&
    Array.isArray(manifest.accounts) && manifest.accounts.length <= 2,
  'Invalid owned-test cleanup manifest');
  const ids = new Set();
  const labels = new Set();
  for (const user of manifest.accounts) {
    require(uuid.test(user.id) && ['a', 'b'].includes(user.label) && !ids.has(user.id) &&
      !labels.has(user.label) &&
      user.email === `axiomara-http-${runId}-${manifest.nonce}-${user.label}@example.invalid`,
    'Cleanup may only name uniquely owned synthetic accounts');
    ids.add(user.id); labels.add(user.label);
  }
  return manifest;
}

export function ownsAccount(user, account, manifest) {
  return user?.id === account.id && user.email === account.email &&
    user.app_metadata?.axiomara_http_test_run === manifest.runId &&
    user.app_metadata?.axiomara_http_test_nonce === manifest.nonce;
}

export async function run(env, cleanupOnly = false) {
  validateContext(env);
  const manifestPath = join(resolve(env.RUNNER_TEMP), `axiomara-http-delete-${env.GITHUB_RUN_ID}.json`);
  const manifest = cleanupOnly ? validateManifest(JSON.parse(readFileSync(manifestPath, 'utf8')),
    env.GITHUB_RUN_ID) : { schemaVersion: 1, runId: env.GITHUB_RUN_ID, nonce: randomUUID(), accounts: [] };
  const service = env.SUPABASE_SECRET_KEY;
  const anon = env.CHRONOSPARK_SUPABASE_ANON_KEY;
  const sessions = [];
  const mask = value => console.log(`::add-mask::${value}`);
  mask(service); mask(anon);
  if (!cleanupOnly) writeFileSync(manifestPath, JSON.stringify(manifest), { mode: 0o600 });
  async function request(path, token, method = 'GET', body, admin = false, origin) {
    const response = await fetch(BASE + path, {
      method, signal: AbortSignal.timeout(30000),
      headers: { apikey: admin ? service : anon, Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json', Prefer: 'return=representation',
        ...(origin ? { Origin: origin } : {}) },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await response.text();
    let data = null;
    try { data = text ? JSON.parse(text) : null; } catch { /* Non-JSON errors stay private. */ }
    return { ok: response.ok, status: response.status, data,
      allowOrigin: response.headers.get('access-control-allow-origin'),
      contract: response.headers.get('x-chronospark-contract') };
  }
  async function cleanup() {
    validateManifest(manifest, env.GITHUB_RUN_ID);
    let cleaned = 0;
    for (const account of manifest.accounts) {
      const current = await request(`/auth/v1/admin/users/${account.id}`, service, 'GET', undefined, true);
      require(current.status === 404 || (current.ok && ownsAccount(current.data, account, manifest)),
        'Cleanup ownership could not be verified');
      // Only the one object path recorded by this run is removed. No bucket-wide deletion.
      const storage = await request('/storage/v1/object/chronospark-sync', service, 'DELETE',
        { prefixes: [`${account.id}/backup/tasks_backup.json`] }, true);
      require(storage.ok || storage.status === 404, 'Synthetic object cleanup failed');
      if (current.ok) {
        const deleted = await request(`/auth/v1/admin/users/${account.id}`, service, 'DELETE', undefined, true);
        require(deleted.ok || deleted.status === 404, 'Synthetic account cleanup failed');
      }
      cleaned += 1;
    }
    return cleaned;
  }
  if (cleanupOnly) return { cleanupComplete: true, cleaned: await cleanup() };
  const checks = {};
  try {
    const denied = await request('/functions/v1/account-delete', 'invalid-test-token', 'POST', { action: 'delete' });
    require(denied.status === 401 && denied.contract === 'account-delete-v2', 'Unauthenticated HTTP guard failed');
    checks.unauthenticatedDenied = true;
    const cors = await request('/functions/v1/account-delete', 'invalid-test-token', 'OPTIONS', undefined,
      false, 'https://chronospark.app');
    require(cors.ok && cors.allowOrigin === 'https://chronospark.app', 'Configured CORS origin failed');
    const foreignCors = await request('/functions/v1/account-delete', 'invalid-test-token', 'OPTIONS', undefined,
      false, 'https://example.invalid');
    require(foreignCors.ok && foreignCors.allowOrigin === null, 'Foreign CORS origin was admitted');
    checks.corsOriginGuard = true;
    for (const label of ['a', 'b']) {
      const email = `axiomara-http-${manifest.runId}-${manifest.nonce}-${label}@example.invalid`;
      const password = randomBytes(36).toString('base64url') + '!aA9';
      mask(password);
      const created = await request('/auth/v1/admin/users', service, 'POST', {
        email, password, email_confirm: true,
        app_metadata: { axiomara_http_test_run: manifest.runId, axiomara_http_test_nonce: manifest.nonce },
      }, true);
      require(created.ok && uuid.test(created.data?.id) && created.data.email === email,
        'Synthetic account creation failed');
      const account = { id: created.data.id, label, email };
      manifest.accounts.push(account);
      writeFileSync(manifestPath, JSON.stringify(manifest), { mode: 0o600 });
      require(ownsAccount(created.data, account, manifest), 'Created account marker differs');
      const login = await request('/auth/v1/token?grant_type=password', anon, 'POST', { email, password });
      require(login.ok && login.data?.access_token && login.data?.refresh_token, 'Synthetic sign-in failed');
      mask(login.data.access_token); mask(login.data.refresh_token);
      const session = { ...account, access: login.data.access_token, refresh: login.data.refresh_token };
      sessions.push(session);
      const snapshot = await request('/rest/v1/cloud_backup_snapshots', session.access, 'POST', {
        user_id: account.id, revision: 1, payload: { syntheticDeletionFixture: manifest.nonce },
      });
      require(snapshot.ok, 'Owner snapshot seed failed');
      const object = await request(`/storage/v1/object/chronospark-sync/${account.id}/backup/tasks_backup.json`,
        session.access, 'POST', { syntheticDeletionFixture: manifest.nonce });
      require(object.ok, 'Owner Storage seed failed');
    }
    const [a, b] = sessions;
    for (const u of sessions) {
      const profile = await request(`/rest/v1/profiles?id=eq.${u.id}`, u.access);
      const snapshot = await request(`/rest/v1/cloud_backup_snapshots?user_id=eq.${u.id}`, u.access);
      require(profile.ok && profile.data?.length === 1 && snapshot.ok && snapshot.data?.length === 1,
        'Seeded owner readback failed');
    }
    const foreign = await request(`/rest/v1/cloud_backup_snapshots?user_id=eq.${a.id}`, b.access);
    require(foreign.ok && foreign.data?.length === 0, 'Cross-account snapshot isolation failed');
    checks.seededOwnerReadsAndIsolation = true;
    let deletion = await request('/functions/v1/account-delete', a.access, 'POST', { action: 'delete' });
    require(deletion.status === 200 || deletion.status === 202, 'Hosted deletion request failed');
    const capability = { requestId: deletion.data?.requestId, receipt: deletion.data?.receipt };
    mask(capability.receipt ?? 'unused-receipt');
    for (let i = 0; deletion.data?.completed !== true && i < 15; i += 1) {
      require(capability.requestId && capability.receipt, 'Deletion status capability missing');
      await new Promise(resolve => setTimeout(resolve, 5000));
      deletion = await request('/functions/v1/account-delete', anon, 'POST', {
        action: 'status', ...capability,
      });
      require(deletion.ok, 'Hosted deletion status failed');
    }
    require(deletion.data?.completed === true, 'Hosted deletion did not complete within bounded polling');
    checks.hostedDeletionCompleted = true;
    const authGone = await request(`/auth/v1/admin/users/${a.id}`, service, 'GET', undefined, true);
    require(authGone.status === 404, 'Deleted Auth account remained');
    for (const table of [`profiles?id=eq.${a.id}`, `cloud_backup_snapshots?user_id=eq.${a.id}`]) {
      const stale = await request('/rest/v1/' + table, a.access);
      require((stale.ok && stale.data?.length === 0) || [401,403].includes(stale.status),
        'Lingering JWT could read retained owned rows');
    }
    const objectGone = await request(`/storage/v1/object/authenticated/chronospark-sync/${a.id}/backup/tasks_backup.json`,
      service, 'GET', undefined, true);
    require(objectGone.status === 404 || (objectGone.status === 400 &&
      String(objectGone.data?.statusCode) === '404' && objectGone.data?.error === 'not_found'),
    'Deleted Storage object remained or readback failed');
    const refresh = await request('/auth/v1/token?grant_type=refresh_token', anon, 'POST', { refresh_token: a.refresh });
    require([400,401].includes(refresh.status), 'Deleted account refresh token remained valid');
    checks.deletedIdentityRowsStorageAndRefreshRevoked = true;
    const other = await request(`/rest/v1/cloud_backup_snapshots?user_id=eq.${b.id}`, b.access);
    const otherObject = await request(`/storage/v1/object/authenticated/chronospark-sync/${b.id}/backup/tasks_backup.json`,
      b.access);
    require(other.ok && other.data?.length === 1 && otherObject.ok, 'Other account data changed');
    checks.otherAccountPreserved = true;
    return { passed: true, observedAt: new Date().toISOString(), project: PROJECT,
      sourceSha: env.ACCEPTANCE_SOURCE_SHA, toolingSha: env.GITHUB_SHA, runId: env.GITHUB_RUN_ID,
      syntheticAccounts: 2, checks,
      boundary: 'Deployed HTTP route, synthetic profile/snapshot/Storage isolation and deletion; not Android Keystore, actual app backup ciphertext or final signed UI acceptance.' };
  } finally {
    await cleanup();
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const result = await run(process.env, process.argv.includes('--cleanup-only'));
    const output = process.env.ACCEPTANCE_RECEIPT;
    if (output && !process.argv.includes('--cleanup-only')) writeFileSync(output, JSON.stringify(result, null, 2));
    console.log(JSON.stringify(result));
  } catch (error) {
    // Never print response bodies, credentials, IDs or arbitrary server text.
    console.error(error instanceof Error && /^[A-Za-z0-9 ,;.-]+$/.test(error.message)
      ? error.message : 'Hosted deletion acceptance failed; private details suppressed');
    process.exitCode = 1;
  }
}
