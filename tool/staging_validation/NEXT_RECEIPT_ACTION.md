# Next Receipt Action

## Next Manual Action

1. Run `apply_verified_purchase_grant_verification.sql` manually against confirmed staging.
2. Capture the results in the required evidence format.
3. Review the results against the expected server-only grant state.
4. If grants are correct, rerun the bypass harness with transcript capture.
5. Review the transcript for all denial and no-mutation assertions.
6. Only then move to receipt mismatch test generation.

Do not proceed if grant evidence is missing, any client role retains EXECUTE, or the bypass transcript is incomplete.

Production release remains **NO**.