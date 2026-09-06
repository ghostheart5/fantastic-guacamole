# Internal assistant candidate inputs

The tracked policy intentionally has an empty cohort. It is not a buildable
allowlist and does not enable any account on its own. A privately verified cohort
is supplied separately. Existing builds without this policy remain off.

Before the later build stage, privately match the authenticated Supabase account
ID to the intended signed-in ChronoSpark tester. Google Play enrollment and an
email address do not establish the local assistant account namespace. Do not use
an ID from another phone, a guessed ID, or a debug tester identity.

From an interactive terminal in the reviewed app checkout, run
`dart run tool/internal_testing_account_digest.dart`. The utility uses the actual
`AccountStorageScope.authenticated(id).v2Namespace` and
`assistantReleaseAccountDigest` implementation, hides input, and saves nothing.
It derives the digest; it cannot independently verify account ownership. The
result is not a credential, but keep the account mapping and cohort input private.

After private account verification, the existing production GitHub environment
needs `CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS` containing canonical lowercase
64-character digests, comma separated for multiple accounts. Creating or updating
that environment secret is a later authorized build preparation step. No secret
was created or read by this repair. The effective policy hash for multiple
accounts must use sorted unique digests and sorted JSON keys, with no whitespace.

The workflow now requires three explicit dispatch inputs with no previous-release
defaults: reviewed full app source SHA, successful exact-source `ci.yml`
workflow-dispatch run ID, and effective internal policy SHA256. Its separately
checked-out tooling must contain the matching repair. Both app and tooling trees
must be clean; the app version code must be at least 2026083004. Uncommitted repair
work is not an immutable release candidate and no green CI is claimed for it.

The candidate runner validates the assembled defines file, including the policy,
then passes that exact file to both the production configuration guard and Flutter.
It preserves cloud authentication, required safety/consent checks, local Planner,
local SI and governed memory. External Planner explanation remains rolled back;
existing external AI, commerce, sync, restore, analytics and crash-reporting
containment remain in force. Malformed or duplicate JSON, unknown keys, a broad
rollout, missing/unsafe cohort, unsafe flag combinations, hash mismatch or stale
CI prevents the candidate build. The public candidate receipt includes only
policy hash, cohort count and effective capabilities, not cohort digests.

The root and `test-results/internal-tooling` copies of the candidate runner, tests
and workflow were deliberately synchronized during this repair. The latter is a
linked tooling worktree and must be reviewed separately; root-only changes do not
update a remote workflow. Nothing has been staged, committed, pushed or built.

After a replacement is explicitly built and installed, verify its exact version
and account cohort, then rerun local SI/Planner and affected phone journeys. Local
test passes cannot close the previously installed binary's capability blockers.

Focused local verification commands (no signing/build/upload):

```text
python -m unittest discover -s scripts -p test_android_candidate_build.py -v
flutter test --no-pub test/release/internal_assistant_production_test.dart test/state/providers/assistant_release_provider_test.dart test/state/controllers/smart_planner_query_controller_test.dart
flutter test --no-pub --dart-define=dart.vm.product=true --dart-define=CHRONOSPARK_APP_FLAVOR=prod --dart-define=CHRONOSPARK_ENABLE_MOCK_MODE=false --dart-define=CHRONOSPARK_ENABLE_MOCK_LOGIN=false --dart-define=CHRONOSPARK_ENABLE_TESTER_FULL_ACCESS=false --dart-define=CHRONOSPARK_ENABLE_RUNTIME_FEATURE_FLAGS=false test/release/internal_assistant_production_test.dart
```

The last command checks product-mode configuration semantics in the Flutter host
test runner. It does not create a release APK or AAB, and does not replace normal
debug assertions, emulator runtime tests or physical-device verification.
