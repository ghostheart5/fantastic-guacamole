# Candidate passport template

Version: `1.0.0`
Passport status: `NOT RUN`

> Create one completed copy per exact release candidate. Do not fill a
> template with assumed results. A changed commit, binary hash, build flavor,
> backend environment or schema version requires a new passport.

## Candidate identity

| Field | Recorded value |
|---|---|
| Passport ID | |
| Commit SHA | |
| Binary filename / immutable location | |
| Binary SHA-256 | |
| Signed build channel | |
| Build flavor | |
| Application ID / package | |
| App version / build number | |
| Backend environment name | |
| Exact backend hostname / project reference | |
| Backend schema version | |
| Candidate created UTC | |

## Execution context

| Field | Recorded value |
|---|---|
| Device-matrix ID | |
| Device model / safe device identifier | |
| OS and version | |
| Screen size, resolution and density | |
| Orientation | |
| Accessibility settings (screen reader, scale, contrast, motion, input) | |
| Tester | |
| Independent verifier | |
| Account persona | |
| Dataset seed/version and run ID | |
| Start UTC | |
| End UTC | |
| Network mode and fault-control method | |

## Case and evidence record

| Case ID | Result | Evidence (screenshots / recording / logs) | Defects / veto | Primary tester | Verifier |
|---|---|---|---|---|---|
| HR-CORE-001 | NOT RUN | | | | |
| Other required registry cases | NOT RUN | | | | |

- Screenshot references and hashes:
- Screen-recording reference and hash:
- Redacted device-log reference and hash:
- Test-data cleanup verification:
- Environment confirmation:
- Unexecuted/blocked cases and reason:

## Final decision

| Field | Recorded value |
|---|---|
| Automatic veto check | |
| Required-case summary | |
| Final decision: GO / NO-GO / BLOCKED | |
| Decision rationale | |
| Primary signature / UTC time | |
| Verifier signature / UTC time | |
| Release Engineering signature / UTC time | |

No signature is implied by creating, committing, or viewing this template.
