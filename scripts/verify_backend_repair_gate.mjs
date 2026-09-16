// Read-only release preflight: fixed catalog SQL, function metadata, GET probes
// and anonymous deletion rejection/status probes. Never accepts caller SQL or
// user tokens; never reserves credits, calls AI, purchases or deletes an account.
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';

export const REPAIR_MIGRATION = '20260909065846';
const COHORT_SETTING = 'CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS';
export const CREDIT_AUTHORITY_FUNCTIONS = [
  'public.consume_monetization_credits(integer,text,jsonb)',
  'public.reserve_ai_usage(uuid,text,integer,text)',
  'public.settle_ai_usage(uuid,text,boolean,integer,integer,text,text,jsonb)',
  'public.read_account_deletion_status(text,text)',
];
const API_ROLES = ['anon', 'authenticated', 'service_role'];

// Primary API: POST /v1/projects/{ref}/database/query/read-only, {query}.
// The endpoint executes as supabase_read_only_user. No rows of user data are
// selected and no application function is executed; these are pg_catalog reads.
export const CREDIT_AUTHORITY_QUERY = `
with expected(signature) as (values
  ('public.consume_monetization_credits(integer,text,jsonb)'),
  ('public.reserve_ai_usage(uuid,text,integer,text)'),
  ('public.settle_ai_usage(uuid,text,boolean,integer,integer,text,text,jsonb)'),
  ('public.read_account_deletion_status(text,text)')
), api_roles(role_name) as (values ('anon'), ('authenticated'), ('service_role'))
select expected.signature, api_roles.role_name,
  pg_catalog.to_regprocedure(expected.signature) is not null as present,
  pg_catalog.has_function_privilege(api_roles.role_name,
    pg_catalog.to_regprocedure(expected.signature), 'EXECUTE') as can_execute
from expected cross join api_roles
order by expected.signature, api_roles.role_name
`;

export class BackendRepairPreflightError extends Error {}
function require(condition, message) {
  if (!condition) throw new BackendRepairPreflightError(message);
}

export function expectedCohortFingerprint(value) {
  const values = typeof value === 'string' ? value.split(',') : [];
  const excluded = ['', 'v2.signed_out', 'v2.unsafe'].map((item) =>
    createHash('sha256').update(item).digest('hex'));
  require(values.length > 0 && values.length <= 100 &&
    new Set(values).size === values.length &&
    values.every((item) => /^[a-f0-9]{64}$/.test(item) && !excluded.includes(item)),
  'Missing or invalid private internal cohort');
  return createHash('sha256').update([...values].sort().join(',')).digest('hex');
}

export function verifyCreditAuthorityGrants(rows) {
  require(Array.isArray(rows) && rows.length === CREDIT_AUTHORITY_FUNCTIONS.length * API_ROLES.length,
    'Backend credit authority privilege inventory is incomplete');
  for (const signature of CREDIT_AUTHORITY_FUNCTIONS) {
    for (const role of API_ROLES) {
      const matches = rows.filter((row) => row?.signature === signature && row.role_name === role);
      const allowed = signature !== CREDIT_AUTHORITY_FUNCTIONS[0] && role === 'service_role';
      require(matches.length === 1 && matches[0].present === true && matches[0].can_execute === allowed,
        'Backend credit authority privileges do not match the reviewed policy');
    }
  }
}

export async function verifyBackendRepairGate(env = process.env, request = fetch) {
  try {
    const setting = (name) => {
      const value = env[name]?.trim();
      require(!!value, `Missing ${name}`);
      return value;
    };
    const project = setting('SUPABASE_PROJECT_REF');
    const root = setting('CHRONOSPARK_SUPABASE_URL').replace(/\/$/, '');
    require(/^[a-z0-9]{20}$/.test(project) && root === `https://${project}.supabase.co`,
      'Backend repair project identity mismatch');
    const managementToken = setting('SUPABASE_ACCESS_TOKEN');
    const serviceKey = setting('SUPABASE_SECRET_KEY');
    const cohortFingerprint = expectedCohortFingerprint(env[COHORT_SETTING]);
    const managementRoot = `https://api.supabase.com/v1/projects/${project}`;
    const managementHeaders = { Authorization: `Bearer ${managementToken}`, 'Content-Type': 'application/json' };
    const serviceHeaders = { Authorization: `Bearer ${serviceKey}`, apikey: serviceKey };
    const response = async (url, init = {}) => await request(url, {
      ...init, redirect: 'error', signal: AbortSignal.timeout(20000),
    });
    const managementJson = async (path, init = {}) => {
      const result = await response(`${managementRoot}${path}`, { ...init, headers: managementHeaders });
      require(result.ok, `Backend management read failed (${result.status})`);
      return await result.json();
    };

    const functions = await managementJson('/functions');
    require(Array.isArray(functions), 'Backend function inventory is invalid');
    for (const [slug, verifyJwt] of [['ai-proxy', true], ['planner-explanation', true], ['account-delete', false]]) {
      const matches = functions.filter((item) => item?.slug === slug);
      require(matches.length === 1 && matches[0].status === 'ACTIVE' &&
        matches[0].verify_jwt === verifyJwt && Number.isSafeInteger(matches[0].version) && matches[0].version > 0,
      `Deployed ${slug} gateway configuration is not ready`);
    }
    const migrations = await managementJson('/database/migrations');
    require(Array.isArray(migrations) && migrations.filter((item) => item?.version === REPAIR_MIGRATION).length === 1,
      'Required credit-authority repair migration is not deployed');
    const privileges = await managementJson('/database/query/read-only', {
      method: 'POST', body: JSON.stringify({ query: CREDIT_AUTHORITY_QUERY }),
    });
    verifyCreditAuthorityGrants(privileges);

    for (const [slug, contract] of [['ai-proxy', 'ai-proxy-v2'], ['planner-explanation', 'planner-explanation-v1']]) {
      const result = await response(`${root}/functions/v1/${slug}`, { headers: serviceHeaders });
      await result.body?.cancel();
      require(result.status === 405 && result.headers.get('x-chronospark-contract') === contract &&
        result.headers.get('x-chronospark-internal-ai-guard') === 'v1' &&
        result.headers.get('x-chronospark-internal-ai-cohort-sha256') === cohortFingerprint,
      `Deployed ${slug} internal AI guard or private cohort does not match`);
    }

    // These are never signed or accompanied by API keys. Deletion must reject
    // before any Auth or mutating backend call. Status probes are capability-
    // bounded reads with synthetic values that cannot identify a real user.
    for (const [body, status, error] of [
      [{ action: 'status', requestId: 'invalid', receipt: 'invalid' }, 400, 'invalid_status_capability'],
      [{ action: 'status', requestId: '0'.repeat(64), receipt: '1'.repeat(64) }, 404, 'deletion_request_not_found'],
      [{ action: 'delete' }, 401, 'unauthorized'],
    ]) {
      const result = await response(`${root}/functions/v1/account-delete`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
      });
      const value = await result.json();
      require(result.status === status && value?.error === error &&
        result.headers.get('x-chronospark-contract') === 'account-delete-v2',
      'Deployed deletion capability gateway or deletion authentication is not ready');
    }
    return {
      schemaVersion: 1,
      internalAiCohortMatched: true,
      obsoleteDebitDenied: true,
      canonicalCreditAuthorityIntact: true,
      deletionCapabilityGateway: true,
      migrationVersion: REPAIR_MIGRATION,
    };
  } catch (error) {
    if (error instanceof BackendRepairPreflightError) throw error;
    // Fetch/JSON errors may carry credentials or raw server bodies. Never relay
    // them to an artifact, shell, GitHub summary or caller.
    throw new BackendRepairPreflightError('Backend repair preflight failed: invalid response or network error');
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    console.log(JSON.stringify(await verifyBackendRepairGate()));
  } catch (error) {
    console.error(error instanceof BackendRepairPreflightError ? error.message : 'Backend repair preflight failed');
    process.exitCode = 1;
  }
}
