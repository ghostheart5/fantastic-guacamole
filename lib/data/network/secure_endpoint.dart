import 'package:supabase_flutter/supabase_flutter.dart' as sb;

Uri? parseSecureHttpsEndpoint(String value) {
  final Uri? uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      !uri.hasAuthority ||
      uri.host.trim().isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

String? currentSupabaseAccessToken() {
  try {
    final String? token =
        sb.Supabase.instance.client.auth.currentSession?.accessToken;
    return token == null || token.trim().isEmpty ? null : token.trim();
  } on Object {
    return null;
  }
}

/// Returns a fresh Supabase access token, proactively refreshing the session
/// if one is active.
///
/// Use this before any authenticated network call to eliminate the edge case
/// where the current token is close to expiry and the SDK has not yet
/// proactively refreshed it, which would cause a 401 from the backend.
///
/// Returns null when there is no active session (unauthenticated).
Future<String?> requireFreshSupabaseToken() async {
  try {
    final sb.SupabaseClient client = sb.Supabase.instance.client;
    if (client.auth.currentSession == null) return null;
    final sb.AuthResponse response = await client.auth.refreshSession();
    final String? token = response.session?.accessToken;
    return token == null || token.trim().isEmpty ? null : token.trim();
  } on Object {
    // Fall back to the cached token if the refresh fails (e.g., offline).
    return currentSupabaseAccessToken();
  }
}
