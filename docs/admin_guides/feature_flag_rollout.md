# Feature Flag Rollout

## Objective
Safely roll out new user-facing behavior with the ability to stop quickly.

## Steps
1. Define default behavior in `feature_flag_repository.dart`.
2. Add the flag to remote config source and verify key names.
3. Gate UI or flows through `featureFlagEnabledProvider`.
4. Verify with `flutter analyze` and `check_architecture.ps1`.
5. Roll out gradually and monitor logs/metrics.

## Rollback
1. Flip remote value to `false`.
2. Confirm behavior fallback in app.
3. Keep code path in place until stable.
