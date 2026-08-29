part of '../env.dart';

abstract final class _ServiceEndpoints {
  static const String _receiptVerifyEndpointOverrideDefine =
      String.fromEnvironment(
        'CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT',
        defaultValue: '',
      );
  static const bool _hasReceiptVerifyEndpointOverrideDefine =
      bool.hasEnvironment('CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT');
  static const String _aiProxyEndpointDefine = String.fromEnvironment(
    'CHRONOSPARK_AI_PROXY_ENDPOINT',
    defaultValue: '',
  );
  static const bool _hasAiProxyEndpointDefine = bool.hasEnvironment(
    'CHRONOSPARK_AI_PROXY_ENDPOINT',
  );
  static const String _aiReportEndpointDefine = String.fromEnvironment(
    'CHRONOSPARK_AI_REPORT_ENDPOINT',
    defaultValue: '',
  );
  static const bool _hasAiReportEndpointDefine = bool.hasEnvironment(
    'CHRONOSPARK_AI_REPORT_ENDPOINT',
  );
  static const String _accountDeleteEndpointDefine = String.fromEnvironment(
    'CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT',
    defaultValue: '',
  );
  static const bool _hasAccountDeleteEndpointDefine = bool.hasEnvironment(
    'CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT',
  );
  static const String _oauthRedirectUrlDefine = String.fromEnvironment(
    'CHRONOSPARK_OAUTH_REDIRECT_URL',
    defaultValue: 'chronospark://auth-callback',
  );
  static const bool _hasOauthRedirectUrlDefine = bool.hasEnvironment(
    'CHRONOSPARK_OAUTH_REDIRECT_URL',
  );
  static const String _githubOauthRedirectUrlDefine = String.fromEnvironment(
    'CHRONOSPARK_GITHUB_OAUTH_REDIRECT_URL',
    defaultValue: _oauthRedirectUrlDefine,
  );
  static const bool _hasGithubOauthRedirectUrlDefine = bool.hasEnvironment(
    'CHRONOSPARK_GITHUB_OAUTH_REDIRECT_URL',
  );
  static const String _supabaseUrlDefine = String.fromEnvironment(
    'CHRONOSPARK_SUPABASE_URL',
    defaultValue: '',
  );
  static const bool _hasSupabaseUrlDefine = bool.hasEnvironment(
    'CHRONOSPARK_SUPABASE_URL',
  );
  static const String _supabaseAnonKeyDefine = String.fromEnvironment(
    'CHRONOSPARK_SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  static const bool _hasSupabaseAnonKeyDefine = bool.hasEnvironment(
    'CHRONOSPARK_SUPABASE_ANON_KEY',
  );

  static String get _receiptVerifyEndpointOverride => Env._readString(
    'CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT',
    _receiptVerifyEndpointOverrideDefine,
    defineProvided: _hasReceiptVerifyEndpointOverrideDefine,
  );

  static String get aiProxyEndpoint => Env._readString(
    'CHRONOSPARK_AI_PROXY_ENDPOINT',
    _aiProxyEndpointDefine,
    defineProvided: _hasAiProxyEndpointDefine,
  );

  static String get aiReportEndpoint => resolveAiReportEndpoint(
    Env._readString(
      'CHRONOSPARK_AI_REPORT_ENDPOINT',
      _aiReportEndpointDefine,
      defineProvided: _hasAiReportEndpointDefine,
    ),
    supabaseUrl: supabaseUrl,
  );

  static String get accountDeleteEndpoint => Env._readString(
    'CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT',
    _accountDeleteEndpointDefine,
    defineProvided: _hasAccountDeleteEndpointDefine,
  );

  static String get oauthRedirectUrl => Env._readString(
    'CHRONOSPARK_OAUTH_REDIRECT_URL',
    _oauthRedirectUrlDefine,
    defineProvided: _hasOauthRedirectUrlDefine,
  );

  static String get githubOauthRedirectUrl => Env._readString(
    'CHRONOSPARK_GITHUB_OAUTH_REDIRECT_URL',
    _githubOauthRedirectUrlDefine,
    defineProvided: _hasGithubOauthRedirectUrlDefine,
  );

  static String get supabaseUrl => Env._readString(
    'CHRONOSPARK_SUPABASE_URL',
    _supabaseUrlDefine,
    defineProvided: _hasSupabaseUrlDefine,
  );

  static String get supabaseAnonKey => Env._readString(
    'CHRONOSPARK_SUPABASE_ANON_KEY',
    _supabaseAnonKeyDefine,
    defineProvided: _hasSupabaseAnonKeyDefine,
  );

  static bool get isSupabaseConfigured =>
      resolveIsSupabaseConfigured(url: supabaseUrl, anonKey: supabaseAnonKey);

  static bool get isAiProxyConfigured =>
      resolveIsAiProxyConfigured(aiProxyEndpoint);

  static bool resolveIsSupabaseConfigured({
    required String url,
    required String anonKey,
  }) {
    return resolveIsValidSupabaseUrl(url) &&
        resolveIsValidSupabaseAnonKey(anonKey);
  }

  static bool resolveIsValidSupabaseUrl(String value) {
    if (!resolveIsValidHttpsEndpoint(value)) {
      return false;
    }
    final Uri uri = Uri.parse(value.trim());
    return uri.path.isEmpty || uri.path == '/';
  }

  static bool resolveIsValidSupabaseAnonKey(String value) {
    final String key = value.trim();
    if (key.length < 32 || key.contains(RegExp(r'\s'))) {
      return false;
    }
    if (RegExp(r'^sb_publishable_[A-Za-z0-9_-]{20,}$').hasMatch(key)) {
      return true;
    }
    final List<String> segments = key.split('.');
    if (segments.length != 3 ||
        segments.any(
          (String segment) => !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(segment),
        )) {
      return false;
    }
    try {
      final Object? payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
      );
      return payload is Map && payload['role'] == 'anon';
    } on FormatException {
      return false;
    }
  }

  static bool resolveIsValidHttpsEndpoint(String endpoint) {
    final String trimmed = endpoint.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final Uri? uri = Uri.tryParse(trimmed);
    return uri != null &&
        uri.hasAuthority &&
        uri.scheme == 'https' &&
        uri.host.trim().isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }

  static bool resolveIsAiProxyConfigured(String endpoint) =>
      resolveIsValidHttpsEndpoint(endpoint);

  static String get receiptVerifyEndpoint => resolveReceiptVerifyEndpoint(
    _receiptVerifyEndpointOverride,
    supabaseUrl: supabaseUrl,
  );

  static String resolveReceiptVerifyEndpoint(
    String configuredValue, {
    required String supabaseUrl,
  }) {
    final String configured = configuredValue.trim();
    if (configured.isNotEmpty) {
      return configured;
    }

    if (resolveIsValidSupabaseUrl(supabaseUrl)) {
      final Uri supabaseUri = Uri.parse(supabaseUrl.trim());
      return supabaseUri.resolve('/functions/v1/verify-receipt').toString();
    }

    return '';
  }

  static String resolveAiReportEndpoint(
    String configuredValue, {
    required String supabaseUrl,
  }) {
    final String configured = configuredValue.trim();
    if (configured.isNotEmpty) {
      return configured;
    }

    if (resolveIsValidSupabaseUrl(supabaseUrl)) {
      final Uri supabaseUri = Uri.parse(supabaseUrl.trim());
      return supabaseUri.resolve('/functions/v1/ai-report').toString();
    }

    return '';
  }
}
