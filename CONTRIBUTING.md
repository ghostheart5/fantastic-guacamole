# Contributing to ChronoSpark

## Commit Message Format

All commits must follow the [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <short summary>

[optional body]
[optional footer]
```

**Types:**

| Type | When to use |
|------|-------------|
| `feat` | New feature or user-visible enhancement |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `test` | Adding or updating tests |
| `refactor` | Code change that is neither a fix nor a feature |
| `perf` | Performance improvement |
| `ci` | CI/CD pipeline changes |
| `chore` | Dependency bumps, tooling, housekeeping |
| `revert` | Reverts a previous commit |

**Scope** (optional, lowercase): the affected module or layer.  
Examples: `auth`, `tasks`, `si-engine`, `paywall`, `settings`, `ci`, `docs`, `web`

**Examples:**
```
feat(tasks): add swipe-to-complete gesture on task card
fix(auth): prevent duplicate sign-in calls on fast taps
docs: add RELEASE_TRACKER.md and RELEASE_INDEX.md
ci(dart): upload JUnit test results as workflow summary
test(paywall): add widget test for restore-purchases loading state
```

## Branch Naming

```
<type>/<short-kebab-description>
```

Examples:
- `feat/paywall-restore-loading-state`
- `fix/deep-link-error-feedback`
- `docs/release-tracker`
- `ci/add-test-summary-upload`

## Pull Request Checklist

Every PR must use the `.github/pull_request_template.md` checklist. Reviewers should not approve unless all mandatory items are checked.

## PR Size

- Keep PRs **small and focused** on a single concern.
- If a PR changes more than ~400 lines of production code, split it unless the scope genuinely requires it.
- Test-only and docs-only PRs are always welcome and can be reviewed quickly.

## CI Requirements

All PRs targeting `main` must pass:

1. **Dart CI** (`dart.yml`) — `flutter analyze` + `flutter test`
2. **CodeQL** (`codeql.yml`) — Swift security analysis

Do not merge a PR that has a failing required check.

## Running Tests Locally

```bash
flutter pub get
flutter analyze
flutter test --coverage
```

Integration tests (requires connected device or emulator):

```bash
flutter test integration_test/
```

## Tester Builds

See [`docs/CLOSED_TESTING_PREP.md`](docs/CLOSED_TESTING_PREP.md) for the QA build command and tester dart-defines.

## Documentation Standards

- Every new feature or significant change must include or update the corresponding flowmap in `docs/flowmaps/`.
- Keep `docs/RELEASE_TRACKER.md` up to date as items are completed.
- Update `docs/FINAL_AUDIT_SCORECARD.md` after each test run.
