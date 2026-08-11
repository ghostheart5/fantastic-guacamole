# Human Root environment requirements

Version: `1.0.0`

## Candidate qualification

Before a human case begins, the primary tester records and independently checks:

- immutable commit SHA and clean candidate provenance;
- SHA-256 of the installed APK/AAB/IPA artifact;
- application version, version code/build number, build flavor, package/bundle
  identifier, signing channel, and release-notes reference;
- exact backend environment name, hostname/project identifier, schema version,
  and environment approval owner;
- whether the run is offline, isolated mock, approved staging, or approved
  sandbox store; a production fallback is prohibited;
- known automated gate blockers, including the current-head status of CI,
  device, Maestro, backend, and migration gates.

If the binary, environment, schema, flavor, signing, or candidate commit cannot
be identified exactly, mark the passport `BLOCKED` and do not execute cases.

## Account and data isolation

- Use only approved non-production persona accounts and run-owned datasets.
- Do not use a service-role credential, administrator credential, personal
  account, production account, real payment method, or copied production data.
- User A and User B data-isolation checks use distinct identities and a unique
  candidate/run seed. Account switching records both identities by alias only.
- Payments use approved sandbox products/receipts. Never trigger a real charge.
- Corruption and migration personas operate only on an approved disposable app
  data copy or seeded test fixture. Do not intentionally corrupt a shared
  backend, shared device, or production account.
- Cleanup is limited to records and storage created by the named seed/run. Verify
  cleanup; never reset a broad database or delete by unscoped pattern.

## Network and fault controls

The tester records the tool and exact configuration used for Wi-Fi/mobile data,
airplane mode, offline, slow network, DNS/proxy, backgrounding, process kill,
clock/timezone change, low storage, permissions, and token/session expiry. Use
observable conditions and bounded waits; do not treat an arbitrary delay as
recovery proof.

No live environment mutation occurs under this document. Approval for a future
case must identify the environment and safe fault method before execution.
