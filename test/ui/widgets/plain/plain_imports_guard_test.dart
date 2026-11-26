import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Any import or export line that points into features/ or data/, whether it is
// a package path or a relative one, or a riverpod import.
final RegExp _bannedImport = RegExp(
  r'''^\s*(import|export)\s+['"][^'"]*(\bfeatures/|\bdata/|flutter_riverpod)''',
  multiLine: true,
);

void main() {
  test('plain kit does not depend on features, data or glass widgets', () {
    final List<File> files = Directory('lib/ui/widgets/plain')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList();
    expect(files, isNotEmpty);
    final RegExp bannedWidget = RegExp(
      r'AnimatedSystemBackground|TemporalGlassSurface|TemporalScreenHeader',
    );
    for (final File file in files) {
      final String source = file.readAsStringSync();
      expect(
        _bannedImport.hasMatch(source),
        isFalse,
        reason: '${file.path} imports features, data or riverpod',
      );
      expect(
        bannedWidget.hasMatch(source),
        isFalse,
        reason: '${file.path} uses a banned glass widget',
      );
    }
  });

  test('the guard pattern catches relative and package imports', () {
    expect(
      _bannedImport.hasMatch("import '../../../features/home/x.dart';"),
      isTrue,
    );
    expect(
      _bannedImport.hasMatch(
        "import 'package:fantastic_guacamole/data/services/a.dart';",
      ),
      isTrue,
    );
    expect(
      _bannedImport.hasMatch("import 'package:flutter/material.dart';"),
      isFalse,
    );
  });
}
