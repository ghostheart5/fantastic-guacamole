import 'package:fantastic_guacamole/features/creator/models/creator_workspace_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CreatorWorkspaceMode', () {
    test('all modes expose non-empty labels and subtitles', () {
      for (final CreatorWorkspaceMode mode in CreatorWorkspaceMode.values) {
        expect(mode.label.trim(), isNotEmpty);
        expect(mode.subtitle.trim(), isNotEmpty);
      }
    });

    test('labels stay unique and user-facing', () {
      final List<String> labels = CreatorWorkspaceMode.values
          .map((CreatorWorkspaceMode mode) => mode.label)
          .toList(growable: false);

      expect(labels.toSet().length, labels.length);
      expect(
        labels,
        containsAll(<String>['Tasks', 'Goals', 'Milestones', 'Plan']),
      );
    });
  });
}
