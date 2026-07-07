// Package imports.
import 'package:url_launcher/url_launcher.dart';

class ExternalUrlService {
  const ExternalUrlService();

  Future<bool> open(
    Uri uri, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) async {
    final bool supported = await canLaunchUrl(uri);
    if (!supported) {
      return false;
    }
    return launchUrl(uri, mode: mode);
  }
}
