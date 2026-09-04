import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active compatibility APIs are owned and not falsely deprecated', () {
    final Map<String, dynamic> manifest =
        jsonDecode(
              File(
                'tool/active_compatibility_manifest.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(manifest['schemaVersion'], 1);

    final Map<String, dynamic> sources =
        manifest['sources'] as Map<String, dynamic>;
    expect(sources, isNotEmpty);

    final List<String> violations = <String>[];
    for (final MapEntry<String, dynamic> entry in sources.entries) {
      final File source = File(entry.key);
      if (!source.existsSync()) {
        violations.add('${entry.key}: source is missing');
        continue;
      }
      final Map<String, dynamic> record = entry.value as Map<String, dynamic>;
      for (final String field in <String>[
        'owner',
        'replacement',
        'removalCriteria',
      ]) {
        if ((record[field]?.toString().trim() ?? '').isEmpty) {
          violations.add('${entry.key}: $field is empty');
        }
      }

      final String contents = source.readAsStringSync();
      if (contents.contains('@Deprecated')) {
        violations.add(
          '${entry.key}: active compatibility source is falsely deprecated',
        );
      }
      if (entry.key.startsWith('lib/domain/') &&
          !contents.contains('CHRONOSPARK-CLASS: LEGACY')) {
        violations.add(
          '${entry.key}: domain compatibility source is not LEGACY',
        );
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
