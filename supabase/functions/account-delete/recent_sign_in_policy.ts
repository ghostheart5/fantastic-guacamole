export const DEFAULT_RECENT_SIGN_IN_SECONDS = 5 * 60;

export function hasRecentSignIn(
  sessionSignInAtSeconds: number | null,
  options: { recentSignInSeconds?: number; now?: Date } = {},
): boolean {
  if (
    sessionSignInAtSeconds === null ||
    !Number.isSafeInteger(sessionSignInAtSeconds) || sessionSignInAtSeconds <= 0
  ) return false;
  const recentSignInSeconds = options.recentSignInSeconds ??
    DEFAULT_RECENT_SIGN_IN_SECONDS;
  if (!Number.isFinite(recentSignInSeconds) || recentSignInSeconds <= 0) {
    return false;
  }
  const ageMs = (options.now ?? new Date()).getTime() -
    sessionSignInAtSeconds * 1000;
  return ageMs >= 0 && ageMs <= recentSignInSeconds * 1000;
}
