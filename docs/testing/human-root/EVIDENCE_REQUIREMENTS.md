# Human Root evidence requirements

Version: `1.0.0`

## Candidate evidence bundle

Store evidence under a candidate-specific external bundle path, not in an
approved visual-baseline directory:

`human-root/<candidate-passport-id>/<case-id>/<timestamp-utc>/`

Each case record links only redacted filenames, hashes, and approved artifact
locations. The release sign-off links the manifest for the entire bundle.

| Evidence | Required for | Minimum content |
|---|---|---|
| Candidate passport | Every case | Exact commit, binary hash, flavor, environment, device/persona/seed |
| Start/end screenshots | Every PASS/FAIL/BLOCKED case | Root arrival and terminal state with candidate/passport reference |
| Screen recording | Core, payment, deletion, failure, interruption, adversarial cases | Reproducible actions and terminal result; no unrelated personal content |
| Device logs | Core and all failures | Time-bounded capture, device/app identifiers, redacted error context |
| Network/fault record | Interruption and offline cases | Method, start/end UTC, observed condition, restoration proof |
| Defect record | Every failure or anomaly | Link to defect template, reproduction, impact, and evidence hashes |
| Independent-verification record | Core, payment, deletion, veto retest | Separate verifier, fresh run or evidence review, signature |

## Redaction and integrity

- Never include passwords, MFA codes, access/refresh tokens, API keys, service
  secrets, purchase tokens, full private notes, full user exports, or unredacted
  personally identifying information.
- Blur or replace sensitive fields before sharing. Keep an unredacted original
  only in the approved restricted incident system when policy permits.
- Preserve original timestamps and calculate a SHA-256 hash for the candidate
  binary and each recording/log archive. Do not overwrite evidence after sign-off.
- If a recording cannot be captured, mark the case `BLOCKED` unless the case
  registry explicitly permits a justified alternative evidence set.

## Evidence review

The primary tester confirms evidence completeness. The independent verifier
checks candidate identity, terminal-state evidence, defect links, and redaction
before signing. A missing, unreadable, mismatched, or unredacted critical artifact
invalidates the case result.
