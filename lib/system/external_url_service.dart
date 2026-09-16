// Package imports.
import 'package:url_launcher/url_launcher.dart';

class ExternalUrlService {
  const ExternalUrlService();

  Future<bool> open(
    Uri uri, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) async {
    final String scheme = uri.scheme.toLowerCase();
    if (scheme == 'mailto' && uri.hasQuery) {
      // Mail apps do not consistently decode form-style '+' as a space.
      // Preserve literal plus signs and encode each mail field as a URI
      // component, including Unicode, newlines and ampersands.
      uri = uri.replace(
        query: uri.queryParametersAll.entries
            .expand(
              (entry) => entry.value.map(
                (value) =>
                    '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(value)}',
              ),
            )
            .join('&'),
      );
    }
    final bool webScheme = scheme == 'http' || scheme == 'https';
    final List<LaunchMode> modes = webScheme
        ? <LaunchMode>[
            mode,
            LaunchMode.platformDefault,
            LaunchMode.inAppBrowserView,
            LaunchMode.inAppWebView,
            LaunchMode.externalApplication,
          ]
        : <LaunchMode>[
            mode,
            LaunchMode.externalApplication,
            LaunchMode.platformDefault,
          ];
    for (final LaunchMode candidate in modes.toSet()) {
      try {
        // Android package visibility can make canLaunchUrl return false even
        // when launch succeeds. Attempt the action and handle actual failure.
        final bool launched = await launchUrl(uri, mode: candidate);
        if (launched) {
          return true;
        }
      } catch (_) {
        // Try the next launch mode.
      }
    }
    return false;
  }
}
