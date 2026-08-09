# Apply Verified Purchase Bypass Verification

## Transcript

- Location: `tool/staging_validation/apply_verified_purchase_bypass_rerun_output.txt`
- Transcript captured: **YES**
- Review method: normalized the UTF-16 PowerShell transcript whitespace before evaluating assertions and summary counts.

## Summary Counts

- PASS: **19**
- FAIL: **0**
- SKIP: **0**
- Process exit status: **0**

## Direct RPC Denial Findings

Captured PASS evidence exists for all required direct-RPC denials:

- Anonymous caller cannot apply a verified purchase.
- User A cannot apply a purchase to User A.
- User A cannot apply a purchase to User B.
- User B cannot apply a purchase to User B.
- User B cannot apply a purchase to User A.

## Mutation Findings

Captured PASS evidence exists for both user-state assertions:

- User A has no unauthorized wallet, purchase, or entitlement mutation.
- User B has no unauthorized wallet, purchase, or entitlement mutation.

These assertions cover client-visible wallet state, purchase-row count, and entitlement-event count before and after the denied probes.

## Missing Evidence

No bypass-scope evidence is missing. Receipt validation still requires deployed Edge Function route confirmation, a safe Google Play test purchase path, and an approved cleanup contract.

## Final Verdict

**PASS**

The provided grant-verification result reports `anon_has_execute = false`, `authenticated_has_execute = false`, and `service_role_has_execute = true`. Together with the captured bypass evidence, this verifies the direct-client grant and denial scope.

Production release remains **NO**.