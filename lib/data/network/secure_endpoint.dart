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

/// Returns a fresh Supabase access token, refreshing the session only when
/// the current token is within 60 seconds of expiry.
///
/// Use this before any authenticated network call to eliminate the edge case
/// where the current token is about to expire and the SDK has not yet
/// proactively refreshed it, which would cause a 401 from the backend.
///
/// Returns null when there is no active session (unauthenticated).
Future<String?> requireFreshSupabaseToken() async {
  try {
    final sb.SupabaseClient client = sb.Supabase.instance.client;
    final sb.Session? session = client.auth.currentSession;
    if (session == null) return null;

    // Only perform a network refresh when the token expires within 60 seconds.
    // This avoids a round-trip on every call while still guarding the expiry
    // edge case that the SDK's proactive refresh window may not yet cover.
    final int nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final bool nearExpiry = (session.expiresAt ?? 0) - nowEpoch < 60;
    if (nearExpiry) {
      final sb.AuthResponse response = await client.auth.refreshSession();
      final String? token = response.session?.accessToken;
      if (token != null && token.trim().isNotEmpty) return token.trim();
    }

    // Token is fresh enough — return the cached value.
    return currentSupabaseAccessToken();
  } on Object {
    // Fall back to the cached token if the refresh fails (e.g., offline).
    return currentSupabaseAccessToken();
  }
}
