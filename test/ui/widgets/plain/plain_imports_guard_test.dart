import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plain kit does not depend on features, data or glass widgets', () {
    final List<File> files = Directory('lib/ui/widgets/plain')
        .listSync()
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList();
    expect(files, isNotEmpty);
    final RegExp banned = RegExp(
      r'package:fantastic_guacamole/(features|data)/'
      r'|AnimatedSystemBackground|TemporalGlassSurface|TemporalScreenHeader'
      r'|flutter_riverpod',
    );
    for (final File file in files) {
      final String source = file.readAsStringSync();
      expect(
        banned.hasMatch(source),
        isFalse,
        reason: '${file.path} uses a banned dependency',
      );
    }
  });
}
