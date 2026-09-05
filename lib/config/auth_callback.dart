/// This native callback is registered in both the app and Supabase Auth.
const String passwordRecoveryRedirectUrl = 'chronospark://auth-callback';

bool isTrustedAuthCallback(Uri uri) {
  if (uri.userInfo.isNotEmpty || uri.hasPort) return false;
  if (uri.scheme == 'chronospark') {
    return uri.host == 'auth-callback' && uri.path.isEmpty;
  }
  return uri.scheme == 'https' &&
      uri.host == 'chronospark.app' &&
      uri.path == '/app/auth/callback';
}
