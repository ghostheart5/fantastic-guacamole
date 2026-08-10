import 'dart:io';

import 'package:fantastic_guacamole/features/creator/ui/creator_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  group('Creator flow contract', () {
    test('Creator screen exists and is importable', () {
      const Widget widget = CreatorScreen();
      expect(widget, isA<CreatorScreen>());
    });

    test('Creator source includes unified creation intents', () {
      final File creator = File('lib/features/creator/ui/creator_screen.dart');
      expect(creator.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(creator).toLowerCase();
      expect(text.contains('creator'), isTrue);
      expect(text.contains('task'), isTrue);
      expect(text.contains('goal'), isTrue);
      expect(text.contains('memory') || text.contains('note'), isTrue);
    });

    test(
      'Creator keeps provider/controller/service/repository wiring references',
      () {
        final String all = SourceTestUtils.readAllConcatenated(
          'lib/features/creator',
        ).toLowerCase();
        final String state = SourceTestUtils.readAllConcatenated(
          'lib/state/providers',
        ).toLowerCase();

        expect(
          all.contains('provider') || state.contains('creator_provider'),
          isTrue,
        );
        expect(
          all.contains('creatoractionsprovider') ||
              state.contains('creatoractionsprovider'),
          isTrue,
        );
      },
    );
  });
}
