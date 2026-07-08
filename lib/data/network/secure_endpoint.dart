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
