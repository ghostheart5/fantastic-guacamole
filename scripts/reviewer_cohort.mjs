// Private cohort preparation only: no purchases, grants, publication or provider calls.
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
const digest = (value) => createHash('sha256').update(value).digest('hex');
const PROJECT = 'qpwhuckyirnqtmvhpede';
const REPOSITORY = 'ghostheart5/fantastic-guacamole';
const COHORT = 'CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS';
function require(value) { if (!value) throw new Error('Reviewer cohort preparation rejected'); }
export function combineCohort(original, reviewer) {
  const values = typeof original === 'string' ? original.split(',') : [];
  const excluded = ['', 'v2.signed_out', 'v2.unsafe'].map(digest);
  require(values.length > 0 && values.length <= 100 && new Set(values).size === values.length);
  require(values.every((v) => /^[a-f0-9]{64}$/.test(v) && !excluded.includes(v)));
  require(typeof reviewer === 'string' && /^[a-f0-9]{64}$/.test(reviewer) && !excluded.includes(reviewer));
  const combined = [...new Set([...values, reviewer])].sort();
  require(combined.length <= 100);
  return combined.join(',');
}
export function validateRun(run, id, sha, path) {
  require(/^[a-f0-9]{40}$/.test(sha ?? '') && /^[1-9][0-9]*$/.test(id ?? ''));
  require(String(run?.id) === id && run.head_sha === sha && run.path === path &&
    run.repository?.full_name === REPOSITORY && run.event === 'workflow_dispatch' &&
    run.status === 'completed' && run.conclusion === 'success');
}
export async function prepare(env = process.env, request = fetch) {
  require(env.GITHUB_ACTIONS === 'true' && env.GITHUB_EVENT_NAME === 'workflow_dispatch' &&
    env.GITHUB_REPOSITORY === REPOSITORY &&
    env.GITHUB_REF === 'refs/heads/fix/app-only-readiness-priority2-20260902');
  require(env.SUPABASE_PROJECT_REF === PROJECT && !!env.SUPABASE_ACCESS_TOKEN && !!env.GH_TOKEN);
  const combined = combineCohort(env[COHORT], env.CHRONOSPARK_REVIEWER_ACCOUNT_DIGEST);
  const policy = JSON.parse(readFileSync('candidate/tool/internal_testing_assistant_release.json', 'utf8'));
  const policyKey = 'assistant_release_internal_account_digests';
  require(policy[policyKey] === '');
  policy[policyKey] = combined;
  const canonical = JSON.stringify(Object.fromEntries(Object.keys(policy).sort().map((key) => [key, policy[key]])));
  const http = async (url, init = {}) => {
    const response = await request(url, { ...init, redirect: 'error', signal: AbortSignal.timeout(30000) });
    require(response.ok); return response;
  };
  for (const [id, path] of [[env.REVIEW_CI_RUN, '.github/workflows/ci.yml'],
    [env.REVIEW_DB_RUN, '.github/workflows/supabase-database.yml']]) {
    const run = await (await http(`https://api.github.com/repos/${REPOSITORY}/actions/runs/${id}`,
      { headers: { Authorization: `Bearer ${env.GH_TOKEN}`, Accept: 'application/vnd.github+json' } })).json();
    validateRun(run, id, env.REVIEW_SOURCE_SHA, path);
  }
  const headers = { Authorization: `Bearer ${env.SUPABASE_ACCESS_TOKEN}`, 'Content-Type': 'application/json' };
  const api = `https://api.supabase.com/v1/projects/${PROJECT}`;
  const query = "select encode(extensions.digest('v2.' || translate(encode(convert_to(id::text,'UTF8'),'base64'),'+/','-_'),'sha256'),'hex') as digest from auth.users where lower(email)='mock@chronospark.app' and email_confirmed_at is not null and not coalesce(is_anonymous,false)";
  const reviewers = await (await http(`${api}/database/query/read-only`,
    { method: 'POST', headers, body: JSON.stringify({ query }) })).json();
  require(Array.isArray(reviewers) && reviewers.length === 1 && reviewers[0].digest === env.CHRONOSPARK_REVIEWER_ACCOUNT_DIGEST);
  const before = await (await http(`${api}/secrets`, { headers })).json();
  const entry = before.filter((item) => item.name === COHORT);
  require(entry.length === 1 && [digest(env[COHORT]), digest(combined)].includes(entry[0].value));
  await http(`${api}/secrets`, { method: 'POST', headers, body: JSON.stringify([{ name: COHORT, value: combined }]) });
  const after = await (await http(`${api}/secrets`, { headers })).json();
  require(after.filter((item) => item.name === COHORT && item.value === digest(combined)).length === 1);
  const receipt = { verified: true, sourceSha: env.REVIEW_SOURCE_SHA, ciRun: env.REVIEW_CI_RUN,
    databaseRun: env.REVIEW_DB_RUN, cohortCount: combined.split(',').length,
    cohortFingerprint: digest(combined), policySha256: digest(canonical) };
  writeFileSync(`${env.RUNNER_TEMP}/reviewer-cohort.json`, JSON.stringify(receipt, null, 2));
  return receipt;
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  prepare().then(() => console.log('Reviewer cohort independently verified.'))
    .catch(() => { console.error('Reviewer cohort preparation failed; no raw API response is logged.'); process.exitCode = 1; });
}
