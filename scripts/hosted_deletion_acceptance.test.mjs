import test from 'node:test';
import assert from 'node:assert/strict';
import { ownsAccount, validateContext, validateManifest } from './hosted_deletion_acceptance.mjs';

const nonce = '01234567-0123-4123-8123-0123456789ab';
const id = '11234567-0123-4123-8123-0123456789ab';
const manifest = { schemaVersion: 1, runId: '123', nonce, accounts: [
  { id, label: 'a', email: `axiomara-http-123-${nonce}-a@example.invalid` },
] };
const env = { GITHUB_ACTIONS: 'true', GITHUB_EVENT_NAME: 'workflow_dispatch',
  GITHUB_REPOSITORY: 'ghostheart5/fantastic-guacamole', GITHUB_ACTOR: 'ghostheart5',
  GITHUB_REF: 'refs/heads/main', GITHUB_RUN_ID: '123',
  CHRONOSPARK_SUPABASE_URL: 'https://qpwhuckyirnqtmvhpede.supabase.co',
  SUPABASE_PROJECT_REF: 'qpwhuckyirnqtmvhpede', SUPABASE_SECRET_KEY: 'synthetic-service',
  CHRONOSPARK_SUPABASE_ANON_KEY: 'synthetic-public', RUNNER_TEMP: '/tmp',
  ACCEPTANCE_SOURCE_SHA: 'a'.repeat(40) };

test('rejects other projects, actors, branches and mutable sources before network access', () => {
  for (const [key, value] of Object.entries({ CHRONOSPARK_SUPABASE_URL: 'https://example.invalid',
    SUPABASE_PROJECT_REF: 'other', GITHUB_ACTOR: 'other', GITHUB_REF: 'refs/heads/topic',
    GITHUB_EVENT_NAME: 'pull_request', ACCEPTANCE_SOURCE_SHA: 'main' })) {
    assert.throws(() => validateContext({ ...env, [key]: value }));
  }
  assert.equal(validateContext(env), env.CHRONOSPARK_SUPABASE_URL);
});

test('cleanup rejects another run, real emails, duplicate IDs and foreign markers', () => {
  assert.equal(validateManifest(manifest, '123'), manifest);
  assert.throws(() => validateManifest(manifest, '456'));
  assert.throws(() => validateManifest({ ...manifest, accounts: [{ ...manifest.accounts[0], email: 'person@example.com' }] }, '123'));
  assert.throws(() => validateManifest({ ...manifest, accounts: [...manifest.accounts, manifest.accounts[0]] }, '123'));
  const user = { id, email: manifest.accounts[0].email,
    app_metadata: { axiomara_http_test_run: '123', axiomara_http_test_nonce: nonce } };
  assert.equal(ownsAccount(user, manifest.accounts[0], manifest), true);
  assert.equal(ownsAccount({ ...user, app_metadata: {} }, manifest.accounts[0], manifest), false);
  assert.equal(ownsAccount({ ...user, email: 'person@example.com' }, manifest.accounts[0], manifest), false);
});
