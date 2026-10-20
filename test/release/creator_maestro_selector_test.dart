import 'dart:io';

import 'package:fantastic_guacamole/l10n/creator_copy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  List<dynamic> commands(String path) =>
      loadYamlDocuments(File(path).readAsStringSync())[1].contents as YamlList;

  Iterable<MapEntry<dynamic, dynamic>> entries(dynamic value) sync* {
    if (value is Map) {
      for (final entry in value.entries) {
        yield entry;
        yield* entries(entry.value);
      }
    } else if (value is Iterable) {
      for (final child in value) {
        yield* entries(child);
      }
    }
  }

  test(
    'manual creator smoke uses the actual save actions and retains durable readback',
    () {
      final flow = commands('.maestro/flows/05-creator.yaml');
      final taps = entries(flow)
          .where((entry) => entry.key == 'tapOn')
          .map((entry) => entry.value)
          .whereType<String>();
      const copy = CreatorCopy(false);
      for (final kind in ['task', 'habit', 'goal']) {
        expect(taps, contains('^${copy.createAction(kind)}\$'));
      }
      final raw = File('.maestro/flows/05-creator.yaml').readAsStringSync();
      // Keep the behaviors previously guarded by the longer two-step flow.
      for (final proof in [
        'SCHEDULED',
        'Maestro smoke task',
        'Pause',
        'Resume',
        'Mark target completed',
        'Completed this day',
        'Skip this day',
        'stopApp',
        'No linked goal',
        'Maestro preserved goal',
      ]) {
        expect(
          raw,
          contains(proof),
          reason: 'Preserve the $proof runtime guard.',
        );
      }
      final receipt = File(
        '.maestro/subflows/verify-creator-saved-receipt.yaml',
      ).readAsStringSync();
      expect(receipt, contains('1 change saved'));
      expect(receipt, contains(r'${SAVED_ITEM}'));
      expect(receipt, contains(copy.undo));
    },
  );

  test('all five smoke flows retain resolvable source-bound dependencies', () {
    final visited = <String>{};
    void visit(String path) {
      final file = File(path).absolute;
      if (!visited.add(file.path)) return;
      for (final entry in entries(commands(file.path))) {
        if (entry.key != 'runFlow') continue;
        final relative = entry.value is String
            ? entry.value as String
            : entry.value is Map
            ? (entry.value as Map)['file'] as String?
            : null;
        if (relative == null) continue;
        final dependency = File.fromUri(file.uri.resolve(relative));
        expect(
          dependency.existsSync(),
          isTrue,
          reason: 'Missing flow dependency $relative',
        );
        visit(dependency.path);
      }
    }

    for (final name in [
      '04-smart-planner',
      '05-creator',
      '06-si-console',
      '07-timeline',
      '08-progression',
    ]) {
      visit('.maestro/flows/$name.yaml');
    }
    final signIn = File('.maestro/subflows/sign-in.yaml').readAsStringSync();
    expect(signIn, contains('visible: "Today"'));
    expect(signIn, contains('assertVisible: "Add a goal, task or habit"'));
    expect(signIn, isNot(contains('NEXUS')));
  });

  for (final String path in <String>[
    '.maestro/flows/05-creator.yaml',
    '.maestro/subflows/create-scheduled-task.yaml',
    '.maestro/flows/priority8-learned-lifecycle.yaml',
  ]) {
    test(
      '$path focuses the accessible title, including merged Android hints',
      () {
        final YamlList commands =
            loadYamlDocuments(File(path).readAsStringSync())[1].contents
                as YamlList;
        final List<String> titleSelectors = commands
            .whereType<YamlMap>()
            .map((YamlMap command) => command['tapOn'])
            .whereType<String>()
            .where((String selector) => selector.contains('Title'))
            .toList();
        expect(titleSelectors, isNotEmpty);
        for (final String selector in titleSelectors) {
          final RegExp matcher = RegExp(selector);
          expect(matcher.hasMatch('Title, required'), isTrue);
          expect(matcher.hasMatch('Title, required\nTitle *'), isTrue);
          expect(matcher.hasMatch('Title, required\r\nTitle *'), isTrue);
          expect(matcher.hasMatch('Description'), isFalse);
          expect(matcher.hasMatch('Task Title, required note'), isFalse);
        }
      },
    );
  }
}
