// One-shot, real Firebase protocol check. No app configuration is changed.
// Protocol references: firebase/firebase-js-sdk installations/functions and
// remote-config/src/client/rest_client.ts. Keys/tokens stay in process memory.
import http from 'node:http';
import { randomBytes, createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';

const project = 'chronospark-app';
const fisSdk = 'w:0.6.24';
const jsSdk = '12.18.0';
const keyId = '1f4879bb-4d01-4f85-86a4-37a1270c2e9b';
const retryMacos = process.argv.includes('--retry-failed-macos');
const source = await readFile('lib/firebase_options.dart', 'utf8');
const clients = [...source.matchAll(/static const FirebaseOptions (\w+) = FirebaseOptions\(([\s\S]*?)\n  \);/g)]
  .filter(match => match[1] !== 'windows')
  .map(match => ({
    platform: match[1],
    appId: match[2].match(/appId:\s*'([^']+)'/)[1],
    key: match[2].match(/apiKey:\s*'([^']+)'/)[1],
  }));
if (clients.length !== 4 || clients.some(c => !c.appId.startsWith('1:956622397052:'))) {
  throw new Error('Unexpected client identity inventory');
}
const report = { project, temporaryKeyId: keyId, fisSdk, jsSdk,
  runMode: retryMacos ? 'retry-only-failed-macos' : 'initial-eight-legs',
  testPolicy: '13 enabled retained APIs, strict subset of proposed22',
  scope: 'FIS and Remote Config protocol only; no native SDK, FCM delivery, telemetry or device proof',
  status: 'READY', results: [] };
const csrf = randomBytes(24).toString('hex');
let started = false;
let origin;
const pendingCleanup = [];
const expiresValid = value => typeof value === 'string' && /^\d+s$/.test(value) && Number(value.slice(0, -1)) > 0;
const headers = key => ({ 'Content-Type': 'application/json', Accept: 'application/json', 'x-goog-api-key': key });
const authHeaders = (key, refresh) => ({ ...headers(key), Authorization: `FIS_v2 ${refresh}` });
const base = `https://firebaseinstallations.googleapis.com/v1/projects/${project}/installations`;
async function request(url, options) {
  const response = await fetch(url, { ...options, redirect: 'error', signal: AbortSignal.timeout(15000) });
  let data = null;
  const body = await response.text();
  if (body) { try { data = JSON.parse(body); } catch { /* report parse absence, never raw body */ } }
  const reasons = (data?.error?.details || []).map(x => x.reason).filter(x => typeof x === 'string' && /^[A-Z_]+$/.test(x));
  return { status: response.status, ok: response.ok, data, reasons };
}
async function cleanup(entry) {
  const result = await request(`${base}/${entry.fid}`, { method: 'DELETE', headers: authHeaders(entry.key, entry.refresh) });
  if (result.ok) entry.cleaned = true;
  return { status: result.status, accepted: result.ok, reasons: result.reasons };
}
async function probe(client, key, policy) {
  const row = { platform: client.platform, appId: client.appId, policy, startedAt: new Date().toISOString(), pass: false, createOutcome: 'UNKNOWN' };
  report.results.push(row);
  const bytes = randomBytes(17); bytes[0] = (bytes[0] & 15) | 112;
  const requestedFid = bytes.toString('base64url').slice(0, 22);
  let entry;
  let stage = 'create';
  try {
    const created = await request(base, { method: 'POST', headers: headers(key), body: JSON.stringify({ fid: requestedFid, authVersion: 'FIS_v2', appId: client.appId, sdkVersion: fisSdk }) });
    const value = created.data;
    const fid = value?.fid || requestedFid;
    row.create = { status: created.status, reasons: created.reasons, validTokens: Boolean(typeof value?.refreshToken === 'string' && value.refreshToken.length && typeof value?.authToken?.token === 'string' && value.authToken.token.length && expiresValid(value?.authToken?.expiresIn)) };
    if (!created.ok && created.status < 500) row.createOutcome = 'REJECTED';
    if (created.ok && /^[cdef][\w-]{21}$/.test(fid) && typeof value?.refreshToken === 'string' && value.refreshToken.length) {
      entry = { fid, key, refresh: value.refreshToken, cleaned: false };
      row.createOutcome = 'CREATED_RECOVERABLE';
      pendingCleanup.push(entry);
      row.disposableFidSha256 = createHash('sha256').update(fid).digest('hex');
    }
    if (!created.ok || !row.create.validTokens || !entry) return;
    stage = 'token';
    const token = await request(`${base}/${fid}/authTokens:generate`, { method: 'POST', headers: authHeaders(key, entry.refresh), body: JSON.stringify({ installation: { sdkVersion: fisSdk, appId: client.appId } }) });
    row.token = { status: token.status, reasons: token.reasons, validToken: Boolean(typeof token.data?.token === 'string' && token.data.token.length && expiresValid(token.data?.expiresIn)) };
    if (!token.ok || !row.token.validToken) return;
    stage = 'remoteConfig';
    const config = await request(`https://firebaseremoteconfig.googleapis.com/v1/projects/${project}/namespaces/firebase:fetch?key=${encodeURIComponent(key)}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Encoding': 'gzip', 'If-None-Match': '*' },
      body: JSON.stringify({ sdk_version: jsSdk, app_instance_id: fid, app_instance_id_token: token.data.token, app_id: client.appId, language_code: 'en-US' }),
    });
    const state = config.data?.state;
    row.remoteConfig = { status: config.status, reasons: config.reasons,
      state: typeof state === 'string' && /^[A-Z_]+$/.test(state) ? state : null,
      parsedJson: config.data !== null, entryCount: Object.keys(config.data?.entries || {}).length,
      valuesActivated: false };
    row.pass = config.status === 200 && config.data !== null && typeof config.data === 'object' && !Array.isArray(config.data) && ['UPDATE', 'NO_TEMPLATE', 'EMPTY_CONFIG'].includes(state);
  } catch (error) {
    row.failure = { stage, type: error?.name === 'TimeoutError' ? 'TIMEOUT' : 'REQUEST_ERROR' };
  } finally {
    if (entry) {
      try { row.cleanup = await cleanup(entry); } catch { row.cleanup = { accepted: false, type: 'REQUEST_ERROR' }; }
      if (!row.cleanup.accepted) row.pass = false;
    }
    row.finishedAt = new Date().toISOString();
  }
}
async function run(testKey) {
  report.status = 'RUNNING'; report.startedAt = new Date().toISOString();
  try {
    for (const policy of retryMacos ? ['temporary13Subset'] : ['baseline25', 'temporary13Subset']) {
      for (const client of retryMacos ? clients.filter(c => c.platform === 'macos') : clients) {
        await probe(client, policy === 'baseline25' ? client.key : testKey, policy);
        if (!report.results.at(-1).pass) { report.status = 'FAILED'; return; }
      }
    }
    report.status = 'PASS_PROTOCOL_ONLY';
  } finally {
    for (const entry of pendingCleanup.filter(x => !x.cleaned)) {
      try { entry.retry = await cleanup(entry); } catch { entry.retry = { accepted: false }; }
    }
    report.cleanup = { created: pendingCleanup.length, accepted: pendingCleanup.filter(x => x.cleaned).length, pending: pendingCleanup.filter(x => !x.cleaned).length, uncertainCreations: report.results.filter(x => x.createOutcome === 'UNKNOWN').length };
    if (report.cleanup.pending) report.status = 'FAILED_CLEANUP_PENDING';
    if (report.cleanup.uncertainCreations) report.status = 'FAILED_CLEANUP_UNCERTAIN';
    if (!report.cleanup.pending) { pendingCleanup.length = 0; for (const client of clients) client.key = ''; }
    report.finishedAt = new Date().toISOString();
    await writeFile(new URL(retryMacos ? './firebase-api-probe-macos-retry-results.json' : './firebase-api-probe-results.json', import.meta.url), JSON.stringify(report, null, 2) + '\n');
    testKey = '';
    console.log(JSON.stringify(report));
  }
}
const page = `<!doctype html><meta charset="utf-8"><title>ChronoSpark isolated Firebase check</title><h1>ChronoSpark isolated Firebase check</h1><p>Temporary key stays in memory. No app config, telemetry or phone changes.</p><form method="post" action="/run" autocomplete="off"><input type="hidden" name="csrf" value="${csrf}"><label>Temporary test key <input type="password" name="key" autocomplete="off" required></label><button>Run focused check</button></form>`;
const server = http.createServer(async (req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Content-Security-Policy', "default-src 'none'; form-action 'self'; frame-ancestors 'none'");
  if (req.headers.host !== new URL(origin).host) { res.writeHead(403).end(); return; }
  if (req.method === 'GET' && req.url === '/') { res.setHeader('Content-Type', 'text/html'); res.end(page); return; }
  if (req.method === 'GET' && req.url === '/status') { res.setHeader('Content-Type', 'application/json'); res.end(JSON.stringify(report, null, 2)); return; }
  if (req.method !== 'POST' || req.url !== '/run' || req.headers.origin !== origin || started) { res.writeHead(403).end(); return; }
  let body = '';
  for await (const chunk of req) { body += chunk; if (body.length > 2048) { res.writeHead(413).end(); return; } }
  const fields = new URLSearchParams(body);
  if (fields.get('csrf') !== csrf || !/^AIza[\w-]{35}$/.test(fields.get('key') || '')) { res.writeHead(400).end('Invalid request'); return; }
  if (started) { res.writeHead(409).end('Already started'); return; }
  started = true;
  void run(fields.get('key')).catch(() => { report.status = 'FAILED_REPORT_WRITE'; });
  body = ''; fields.delete('key');
  res.writeHead(303, { Location: '/status' }).end();
});
server.listen(0, '127.0.0.1', () => {
  origin = `http://127.0.0.1:${server.address().port}`;
  console.log(`LOCAL_PROBE_URL=${origin}`);
});
