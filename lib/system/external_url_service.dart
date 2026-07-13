// Package imports.
import 'package:url_launcher/url_launcher.dart';

class ExternalUrlService {
  const ExternalUrlService();

  Future<bool> open(
    Uri uri, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) async {
    final String scheme = uri.scheme.toLowerCase();
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
        final bool supported = await canLaunchUrl(uri);
        if (!supported) {
          continue;
        }
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
