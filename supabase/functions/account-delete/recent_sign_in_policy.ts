export const DEFAULT_RECENT_SIGN_IN_SECONDS = 5 * 60;

export function hasRecentSignIn(
  lastSignInAt: string | null,
  options: { recentSignInSeconds?: number; now?: Date } = {},
): boolean {
  if (!lastSignInAt) return false;
  const signedInAt = Date.parse(lastSignInAt);
  if (!Number.isFinite(signedInAt)) return false;
  const recentSignInSeconds = options.recentSignInSeconds ??
    DEFAULT_RECENT_SIGN_IN_SECONDS;
  if (!Number.isFinite(recentSignInSeconds) || recentSignInSeconds <= 0) {
    return false;
  }
  const ageMs = (options.now ?? new Date()).getTime() - signedInAt;
  return ageMs >= 0 && ageMs <= recentSignInSeconds * 1000;
}
