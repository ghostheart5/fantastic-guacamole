import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lib corruption audit', () {
    test('all lib dart files are readable and not corrupted', () {
      final List<File> files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File file) => file.path.endsWith('.dart'))
          .toList(growable: false);

      expect(files, isNotEmpty);

      for (final File file in files) {
        final List<int> bytes = file.readAsBytesSync();
        final String content = file.readAsStringSync();

        expect(bytes.contains(0), isFalse, reason: file.path);
        expect(content.contains('<<<<<<<'), isFalse, reason: file.path);
        expect(content.contains('======='), isFalse, reason: file.path);
        expect(content.contains('>>>>>>>'), isFalse, reason: file.path);
      }
    });
  });
}
