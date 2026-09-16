import test from 'node:test';
import assert from 'node:assert/strict';
import {
  CREDIT_AUTHORITY_FUNCTIONS, CREDIT_AUTHORITY_QUERY, REPAIR_MIGRATION,
  expectedCohortFingerprint, verifyBackendRepairGate, verifyCreditAuthorityGrants,
} from './verify_backend_repair_gate.mjs';

const project = 'a'.repeat(20);
const root = `https://${project}.supabase.co`;
const env = {
  SUPABASE_PROJECT_REF: project, CHRONOSPARK_SUPABASE_URL: root,
  SUPABASE_ACCESS_TOKEN: 'synthetic-private-management-token',
  SUPABASE_SECRET_KEY: 'synthetic-private-service-key',
  CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS: 'b'.repeat(64),
};
function grants() {
  return CREDIT_AUTHORITY_FUNCTIONS.flatMap((signature, index) =>
    ['anon', 'authenticated', 'service_role'].map((role_name) => ({
      signature, role_name, present: true, can_execute: index !== 0 && role_name === 'service_role',
    })));
}
function fixture(overrides = {}) {
  const state = {
    functions: [
      { slug: 'ai-proxy', status: 'ACTIVE', version: 16, verify_jwt: true },
      { slug: 'planner-explanation', status: 'ACTIVE', version: 2, verify_jwt: true },
      { slug: 'account-delete', status: 'ACTIVE', version: 12, verify_jwt: false },
    ],
    migrations: [{ version: REPAIR_MIGRATION }], privileges: grants(),
    aiStatus: 405, guard: 'v1', cohort: expectedCohortFingerprint(env.CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS),
    statusMalformed: 400, statusUnknown: 404, deleteStatus: 401,
    ...overrides,
  };
  const calls = [];
  const request = async (url, init) => {
    calls.push({ url, init });
    assert.equal(init.redirect, 'error');
    assert.ok(init.signal instanceof AbortSignal);
    const headers = new Headers(init.headers);
    if (url.startsWith('https://api.supabase.com/')) {
      assert.equal(headers.get('authorization'), `Bearer ${env.SUPABASE_ACCESS_TOKEN}`);
      if (url.endsWith('/functions')) return Response.json(state.functions);
      if (url.endsWith('/database/migrations')) return Response.json(state.migrations);
      assert.equal(url, `https://api.supabase.com/v1/projects/${project}/database/query/read-only`);
      assert.equal(init.method, 'POST');
      assert.deepEqual(JSON.parse(init.body), { query: CREDIT_AUTHORITY_QUERY });
      return Response.json(state.privileges, { status: 201 });
    }
    if (url === `${root}/functions/v1/account-delete`) {
      assert.equal(init.method, 'POST');
      assert.equal(headers.has('authorization'), false);
      assert.equal(headers.has('apikey'), false);
      const body = JSON.parse(init.body);
      if (body.action === 'delete') {
        assert.deepEqual(body, { action: 'delete' });
        return Response.json({ error: 'unauthorized' }, { status: state.deleteStatus, headers: { 'x-chronospark-contract': 'account-delete-v2' } });
      }
      assert.equal(body.action, 'status');
      const malformed = body.requestId === 'invalid';
      if (!malformed) assert.deepEqual(body, { action: 'status', requestId: '0'.repeat(64), receipt: '1'.repeat(64) });
      return Response.json({ error: malformed ? 'invalid_status_capability' : 'deletion_request_not_found' }, {
        status: malformed ? state.statusMalformed : state.statusUnknown,
        headers: { 'x-chronospark-contract': 'account-delete-v2' },
      });
    }
    assert.equal(init.method, undefined);
    assert.equal(headers.get('authorization'), `Bearer ${env.SUPABASE_SECRET_KEY}`);
    assert.equal(headers.get('apikey'), env.SUPABASE_SECRET_KEY);
    assert.ok([`${root}/functions/v1/ai-proxy`, `${root}/functions/v1/planner-explanation`].includes(url));
    return Response.json({ error: 'method_not_allowed' }, { status: state.aiStatus, headers: {
      'x-chronospark-contract': url.endsWith('/ai-proxy') ? 'ai-proxy-v2' : 'planner-explanation-v1',
      'x-chronospark-internal-ai-guard': state.guard,
      'x-chronospark-internal-ai-cohort-sha256': state.cohort,
    } });
  };
  return { request, state, calls };
}

test('repair gate uses only scoped read-only inventory and safe probes, emits no private identities', async () => {
  const f = fixture();
  const result = await verifyBackendRepairGate(env, f.request);
  assert.deepEqual(result, {
    schemaVersion: 1, internalAiCohortMatched: true, obsoleteDebitDenied: true,
    canonicalCreditAuthorityIntact: true, deletionCapabilityGateway: true,
    migrationVersion: REPAIR_MIGRATION,
  });
  assert.equal(f.calls.length, 8);
  for (const value of Object.values(env)) assert.equal(JSON.stringify(result).includes(value), false);
  assert.match(CREDIT_AUTHORITY_QUERY, /pg_catalog\.has_function_privilege/);
  assert.doesNotMatch(CREDIT_AUTHORITY_QUERY, /\b(insert|update|delete|alter|grant|revoke|create|drop|call)\b/i);
});

test('missing credentials, malformed cohort and wrong project stop before any network request', async () => {
  for (const overrides of [
    { SUPABASE_ACCESS_TOKEN: '' }, { SUPABASE_SECRET_KEY: '' },
    { CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS: '' }, { CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS: '*' },
    { CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS: `${'b'.repeat(64)},${'b'.repeat(64)}` },
    { CHRONOSPARK_SUPABASE_URL: 'https://other.example' },
  ]) {
    let calls = 0;
    await assert.rejects(verifyBackendRepairGate({ ...env, ...overrides }, async () => { calls++; throw new Error('unexpected'); }));
    assert.equal(calls, 0);
  }
});

test('missing, disabled, duplicate or incorrectly secured deployments stop readiness', async () => {
  for (const change of [
    (f) => f.state.functions.pop(),
    (f) => f.state.functions.push(f.state.functions[0]),
    (f) => { f.state.functions[0].verify_jwt = false; },
    (f) => { f.state.functions[2].verify_jwt = true; },
    (f) => { f.state.functions[1].status = 'INACTIVE'; },
    (f) => { f.state.functions[0].version = 0; },
    (f) => { f.state.migrations = []; },
  ]) {
    const f = fixture(); change(f);
    await assert.rejects(verifyBackendRepairGate(env, f.request));
  }
});

test('old guard, missing server cohort and mismatch fail before signing readiness', async () => {
  for (const overrides of [{ guard: '' }, { cohort: '' }, { cohort: 'c'.repeat(64) }, { aiStatus: 503 }]) {
    const f = fixture(overrides);
    await assert.rejects(verifyBackendRepairGate(env, f.request), /guard or private cohort/);
    assert.equal(f.calls.some((call) => call.url.endsWith('/account-delete')), false);
  }
});

test('every retired/canonical grant, missing function or duplicate inventory row must match', () => {
  assert.doesNotThrow(() => verifyCreditAuthorityGrants(grants()));
  for (let i = 0; i < grants().length; i++) {
    const changed = grants(); changed[i].can_execute = !changed[i].can_execute;
    assert.throws(() => verifyCreditAuthorityGrants(changed));
    changed[i].present = false;
    assert.throws(() => verifyCreditAuthorityGrants(changed));
  }
  assert.throws(() => verifyCreditAuthorityGrants(grants().slice(1)));
  const duplicate = grants(); duplicate[0] = duplicate[1];
  assert.throws(() => verifyCreditAuthorityGrants(duplicate));
});

test('deletion gateway rejection and unauthenticated mutation acceptance cannot pass', async () => {
  for (const overrides of [{ statusMalformed: 401 }, { statusUnknown: 401 }, { deleteStatus: 200 }]) {
    const f = fixture(overrides);
    await assert.rejects(verifyBackendRepairGate(env, f.request), /deletion capability gateway/);
  }
});

test('management and transport errors never expose tokens or remote response bodies', async () => {
  for (const request of [
    async () => { throw new Error(env.SUPABASE_ACCESS_TOKEN); },
    async () => new Response(env.SUPABASE_SECRET_KEY, { status: 403 }),
    async () => new Response(env.CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS),
  ]) {
    await assert.rejects(verifyBackendRepairGate(env, request), (error) => {
      for (const value of Object.values(env)) assert.equal(error.message.includes(value), false);
      return true;
    });
  }
});
