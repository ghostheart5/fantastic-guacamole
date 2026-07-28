import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lib corruption audit', () {
    test('all lib Dart files are readable and not corrupted', () {
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList();

      expect(files, isNotEmpty);

      for (final file in files) {
        final bytes = file.readAsBytesSync();
        final content = file.readAsStringSync();

        expect(bytes.contains(0), isFalse, reason: file.path);
        expect(content.contains('<<<<<<<'), isFalse, reason: file.path);
        expect(content.contains('======='), isFalse, reason: file.path);
        expect(content.contains('>>>>>>>'), isFalse, reason: file.path);
      }
    });
  });
}
