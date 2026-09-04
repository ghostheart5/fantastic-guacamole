# Safe-quick repair plan: Phase 5 hold and Phase 6 preflight

Recorded: 2026-09-04. Repository: `ghostheart5/fantastic-guacamole`.
Checkout: `ChronoSpark-app-only-priority2`.
Branch: `fix/app-only-readiness-priority2-20260902`.
Inspected source HEAD: `cee15e6cb1129b253f92620fcf47d701fbfc3112`.

These are the website/domain and signed-candidate phases from the agreed
13-phase safe-quick repair plan. They are not binder Priority 5/6 or the older
`LAUNCH_READINESS_TRACKER.md` checkpoint numbering.

## Phase 5 - INCOMPLETE / DEFERRED

User direction: save this phase as incomplete and begin Phase 6 preparation.
Do not forget this hold or infer release approval from moving to the next phase.

### Verified configuration on 2026-09-04

- GoDaddy account lists `chronospark.app`; auto-renew shows September 4, 2027
  at $27.99/year.
- GitHub Pages custom domain is `chronospark.app` for the named repository.
  Publishing remains the existing custom Actions workflow; no source merge,
  public-copy deployment, or new CNAME file was made during domain connection.
- GoDaddy apex A records: `185.199.108.153`, `185.199.109.153`,
  `185.199.110.153`, `185.199.111.153`.
- `www` CNAME: `ghostheart5.github.io`.
- Saved DNS UI and public resolver `1.1.1.1` readbacks match. GitHub Pages
  health reports both apex and www as valid, served by Pages and HTTPS-eligible.
- Existing home, `/privacy/`, `/terms/`, `/support/`, `/delete-account/`, and
  `/.well-known/assetlinks.json` returned HTTP 200. HTTP www redirects to apex.
  The association file names `com.ghostheart5.chronospark`; it is not proof of
  device association or an accepted Play signing identity.
- GhostHeart domains, nameservers, and unrelated mail records were untouched.

### Outstanding exit checks

- [ ] Recheck certificate issuance. Last check: GitHub returned
  `The certificate does not exist yet`; strict HTTPS requests failed hostname
  validation. Do not bypass TLS validation.
- [ ] Enable HTTPS enforcement after issuance and read back the setting.
- [ ] Verify HTTPS for apex and www, redirect behavior, every public route,
  styles/assets, and downloadable information.
- [ ] Publish the authorized final legal source through the intended release
  workflow and independently compare live content. The adult-only policy
  commit is local; the HTTP route checks did not prove current legal parity.
- [ ] Verify the App Links file over HTTPS against the actual release/Play
  signing certificate, then verify the exact installed build's association.
- [ ] Send a real support request and verify mailbox delivery and readback.

Resume with a read-only Pages/certificate check. DNS is already configured:
do not purchase again or repeatedly replace records while awaiting issuance.
No background monitoring was scheduled.

## Phase 6 - STARTED; production build BLOCKED at preflight

Follow-up: exact-source CI run `33924430045` passed for checkpoint commit
`9e1ba13376d0747fa6393f428d66f71f353985a5`. An isolated clean checkout was
prepared. Existing signing and configuration secret names were found across
GitHub repository and production-environment scopes; values and actual signing
usability remain unverified. The proposed
[build-only workflow](PHASE_6_BUILD_ONLY_WORKFLOW.md) was prepared and approved
for commit/push, narrow registration, exact branch access and one execution.
Registration is blocked by main's enforced PR/check requirements under the
no-full-suite-rerun constraint. Branch access and execution have not occurred.
The historical preflight findings below remain dated evidence, not current
claims that the new commit lacks CI or that GitHub lacks configuration.

Scope: produce one signed production AAB tied to one green source commit,
using the existing authorized signing identity. No replacement key, Play
upload, submission, rollout, provider enablement, or full-suite rerun authorized
by this checkpoint.

### Source/static and host evidence

- PASS: `pwsh -NoProfile -File scripts/release_guard.ps1`; its nested version
  consistency guard also passed on the inspected source.
- Package configuration: `com.ghostheart5.chronospark`.
- Committed version: `4.1.0+2026083003`, consistent with Gradle. Whether this
  code exceeds every previously uploaded Play version is NOT VERIFIED.
- Compile/target SDK source floors: API 36. Actual AAB manifest: NOT BUILT.
- Source `LaunchContainment` keeps external AI, subscriptions, credit spending,
  cloud sync/restore, analytics and crash reporting disabled.
- Guarded production runner sets prod flavor and readiness enforcement, and
  disables mock login, mock mode, tester full access and runtime feature flags.
- `android/app/google-services.json` exists. Values were not exposed.
- Last observed successful CI/CD run: `33920703693`, source
  `d4499be697c8102b9b50d493b3d2c0248d54b3cc`. This is an ancestor, not current HEAD.
- No CI run was returned for current HEAD. No full suite was run or rerun here.

### Build blockers and smallest next actions

1. Phase 5 secure URLs and final public policy parity remain open. Preparation
   may proceed, but do not claim the candidate's release prerequisites passed.
2. Current legal-policy HEAD has no exact-SHA CI evidence. Freeze the intended
   candidate, then obtain one exact-SHA green run through separately authorized
   commit/push/CI steps; do not substitute the ancestor's pass.
3. The production runner requires a clean snapshot, including untracked files.
   This checkout contains preserved user evidence under `artifacts/**` and now
   these status notes. Use an isolated clean candidate checkout after source
   freeze; never delete evidence or weaken the guard to satisfy it.
4. The guarded runner requires external signing-properties and keystore paths.
   No existing authorized external paths were resolved during this preflight.
   Neither temporary in-repository signing file exists. Do not create a key or
   ask for passwords in chat; resolve the existing identity before building.
5. All six required runner settings are absent from Process/User/Machine
   environment, and this checkout has no `.env`: `CHRONOSPARK_SUPABASE_URL`,
   `CHRONOSPARK_SUPABASE_ANON_KEY`, `CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT`,
   `CHRONOSPARK_AI_PROXY_ENDPOINT`, `CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT`,
   `CHRONOSPARK_ANDROID_SHA256_CERT`. Only presence was inspected, not values.
   Resolve the approved production configuration securely; do not invent
   endpoints or reuse QA configuration. This does not prove CI secrets absent.

### Artifact gate - all remain open

- [ ] Build the production AAB from the frozen green source.
- [ ] Verify package/version and strictly increasing Play version code.
- [ ] Verify existing upload certificate and distinguish it from Play signing.
- [ ] Record source SHA, AAB SHA-256 and build provenance.
- [ ] Run bundletool validation and inspect actual target SDK.
- [ ] Verify 16 KB bundle ZIP and native ELF alignment and retain evidence.
- [ ] Capture mapping/native symbols where applicable.
- [ ] Verify compiled mock/test switches and AI/billing containment.

Device/runtime: NOT RUN. Human evidence: NOT RUN. Live backend and Play
evidence: NOT RUN. Signed artifact: NOT PRODUCED.

Current official references reviewed for preflight:

- [Google Play target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)
- [Android 16 KB page-size verification](https://developer.android.com/guide/practices/page-sizes)

Final release-gate status: **not ready**.
