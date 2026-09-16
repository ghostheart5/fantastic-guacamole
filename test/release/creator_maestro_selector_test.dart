import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
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
