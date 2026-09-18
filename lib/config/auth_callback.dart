/// This native callback is registered in both the app and Supabase Auth.
const String passwordRecoveryRedirectUrl = 'chronospark://auth-callback';

bool isTrustedAuthCallback(Uri uri) {
  if (uri.userInfo.isNotEmpty || uri.hasPort) return false;
  return uri.scheme == 'chronospark' &&
      uri.host == 'auth-callback' &&
      uri.path.isEmpty;
}
