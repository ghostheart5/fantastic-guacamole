export const DEFAULT_RECENT_SIGN_IN_SECONDS = 600;
export const DEFAULT_ALLOWED_CLOCK_SKEW_SECONDS = 120;

type RecentSignInPolicyOptions = {
  now?: number;
  recentSignInSeconds?: number;
  allowedClockSkewSeconds?: number;
};

export function hasRecentSignIn(
  lastSignInAt: string | null,
  options: RecentSignInPolicyOptions = {},
): boolean {
  if (!lastSignInAt) return false;
  const signedInAt = Date.parse(lastSignInAt);
  if (!Number.isFinite(signedInAt)) return false;

  const now = options.now ?? Date.now();
  const recentSignInSeconds = options.recentSignInSeconds ??
    DEFAULT_RECENT_SIGN_IN_SECONDS;
  const allowedClockSkewSeconds = options.allowedClockSkewSeconds ??
    DEFAULT_ALLOWED_CLOCK_SKEW_SECONDS;
  if (recentSignInSeconds <= 0 || allowedClockSkewSeconds < 0) return false;

  const ageMs = now - signedInAt;
  return ageMs >= -(allowedClockSkewSeconds * 1000) &&
    ageMs < recentSignInSeconds * 1000;
}
