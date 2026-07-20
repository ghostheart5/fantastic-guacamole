const http = require('http');

const port = process.env.PORT ? Number(process.env.PORT) : 8787;
const host = '127.0.0.1';
const expectedKey = process.env.CHRONOSPARK_RECEIPT_VERIFY_KEY || '';
const insecureLocalStubAllowed = process.env.CHRONOSPARK_ALLOW_INSECURE_LOCAL_STUB === 'true';

if (process.env.NODE_ENV === 'production') {
  throw new Error('receipt_verifier_stub.js must never run in production.');
}

if (!expectedKey && !insecureLocalStubAllowed) {
  throw new Error(
    'Set CHRONOSPARK_RECEIPT_VERIFY_KEY or CHRONOSPARK_ALLOW_INSECURE_LOCAL_STUB=true for local-only testing.',
  );
}

function send(res, code, payload) {
  res.writeHead(code, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(payload));
}

const server = http.createServer((req, res) => {
  if (req.method !== 'POST' || req.url !== '/monetization-verify') {
    return send(res, 404, { valid: false, reason: 'not_found' });
  }

  if (expectedKey) {
    const auth = req.headers.authorization || '';
    const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
    if (token !== expectedKey) {
      return send(res, 401, { valid: false, reason: 'unauthorized' });
    }
  }

  let raw = '';
  req.on('data', (chunk) => {
    raw += chunk;
  });

  req.on('end', () => {
    try {
      const body = JSON.parse(raw || '{}');
      const hasProduct = typeof body.productId === 'string' && body.productId.length > 0;
      const hasServerToken =
        body.verificationData &&
        typeof body.verificationData.serverVerificationData === 'string' &&
        body.verificationData.serverVerificationData.length > 0;

      if (!hasProduct || !hasServerToken) {
        return send(res, 400, { valid: false, reason: 'missing_fields' });
      }

      // Stub behavior: accepts any purchase payload that has the required fields.
      // Replace with Google Play Developer API / App Store verification in production.
      return send(res, 200, {
        valid: true,
        entitlement: 'premium',
        productId: body.productId,
      });
    } catch (e) {
      return send(res, 400, { valid: false, reason: 'invalid_json' });
    }
  });
});

server.listen(port, host, () => {
  console.log(`ChronoSpark receipt verifier stub listening on http://${host}:${port}`);
});
