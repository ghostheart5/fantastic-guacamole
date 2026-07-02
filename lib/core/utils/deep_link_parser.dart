const Set<String> supportedWebHosts = <String>{
  'ghostheart5.github.io',
  'chronospark.app',
  'www.chronospark.app',
};

const Set<String> supportedDeepLinkTargets = <String>{
  'nexus',
  'creator',
  'logs',
  'temporal',
  'si',
  'si-console',
  'siconsole',
  'settings',
};

String? extractAppLinkTarget(Uri uri) {
  final List<String> segments = uri.pathSegments
      .where((String s) => s.trim().isNotEmpty)
      .map((String s) => s.trim().toLowerCase())
      .toList();
  if (segments.isEmpty) {
    final String queryTarget = (uri.queryParameters['target'] ?? '')
        .trim()
        .toLowerCase();
    return supportedDeepLinkTargets.contains(queryTarget) ? queryTarget : null;
  }

  int index = 0;
  if (segments.first == 'fantastic-guacamole') {
    index = 1;
  }
  if (segments.length <= index) {
    final String queryTarget = (uri.queryParameters['target'] ?? '')
        .trim()
        .toLowerCase();
    return supportedDeepLinkTargets.contains(queryTarget) ? queryTarget : null;
  }
  if (segments[index] == 'app') {
    index += 1;
  }
  if (segments.length <= index) {
    final String queryTarget = (uri.queryParameters['target'] ?? '')
        .trim()
        .toLowerCase();
    return supportedDeepLinkTargets.contains(queryTarget) ? queryTarget : null;
  }

  final String candidate = segments[index];
  if (supportedDeepLinkTargets.contains(candidate)) {
    return candidate;
  }
  return null;
}

Uri? normalizeSupportedDeepLink(Uri uri) {
  final String scheme = uri.scheme.toLowerCase();
  if (scheme == 'chronospark') {
    return uri;
  }
  if (scheme != 'https' && scheme != 'http') {
    return null;
  }
  if (!supportedWebHosts.contains(uri.host.toLowerCase())) {
    return null;
  }
  final String? target = extractAppLinkTarget(uri);
  if (target == null) {
    return null;
  }
  return Uri.parse('chronospark://$target');
}
