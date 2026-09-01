import 'package:fantastic_guacamole/app/app_root.dart';
import 'package:fantastic_guacamole/app/router/deep_link_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeepLinkEventDeduplicator', () {
    test('handles one delivered event only once', () {
      final DeepLinkEventDeduplicator deduplicator =
          DeepLinkEventDeduplicator();
      final Uri link = Uri.parse('https://chronospark.app/app/creator');
      final DeepLinkState event = DeepLinkState(latestUri: link);
      int handledCount = 0;

      deduplicator.handleIfNew(event, (Uri uri) {
        expect(uri, link);
        handledCount += 1;
      });
      deduplicator.handleIfNew(event, (Uri uri) {
        handledCount += 1;
      });

      expect(handledCount, 1);
    });

    test('handles a later event carrying the same valid URI', () {
      final DeepLinkEventDeduplicator deduplicator =
          DeepLinkEventDeduplicator();
      final Uri link = Uri.parse('https://chronospark.app/app/creator');
      final Uri otherLink = Uri.parse('https://chronospark.app/app/settings');
      final List<Uri> handledLinks = <Uri>[];

      deduplicator.handleIfNew(
        DeepLinkState(latestUri: link),
        handledLinks.add,
      );
      deduplicator.handleIfNew(
        DeepLinkState(latestUri: otherLink),
        handledLinks.add,
      );
      deduplicator.handleIfNew(
        DeepLinkState(latestUri: link),
        handledLinks.add,
      );

      expect(handledLinks, <Uri>[link, otherLink, link]);
    });
  });
}
