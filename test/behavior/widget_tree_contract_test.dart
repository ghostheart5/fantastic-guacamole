import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

bool _isWidgetSurfacePath(String path) {
  const List<String> uiFolders = <String>[
    '/ui/',
    '/widgets/',
    '/presentation/',
    '/app/',
  ];
  final bool inSurface = uiFolders.any(path.contains);
  if (!inSurface) {
    return false;
  }
  return !path.contains('/domain/usecases/');
}

bool _hasWidgetHintInFilename(String path) {
  final String fileName = path.split('/').last;
  const List<String> hints = <String>[
    'screen',
    'page',
    'view',
    'panel',
    'card',
    'button',
    'tile',
    'overlay',
    'shell',
    'hub',
  ];
  return hints.any(fileName.contains);
}

void main() {
  group('Widget tree contract', () {
    test('widget-like files define widgets/build methods', () {
      final List<String> offenders = <String>[];
      const List<String> signatures = <String>[
        'extends StatelessWidget',
        'extends StatefulWidget',
        'extends ConsumerWidget',
        'extends ConsumerStatefulWidget',
        'extends HookWidget',
        'Widget build(',
      ];

      for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
        final String path = SourceTestUtils.normalizePath(
          file.path,
        ).toLowerCase();
        if (!_isWidgetSurfacePath(path) || !_hasWidgetHintInFilename(path)) {
          continue;
        }

        final String text = SourceTestUtils.readText(file);
        if (path.contains('/presentation/') &&
            !text.contains('package:flutter/') &&
            !text.contains('package:flutter_riverpod/')) {
          continue;
        }
        if (!signatures.any(text.contains)) {
          offenders.add(SourceTestUtils.normalizePath(file.path));
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Widget-like files without widget signatures: $offenders',
      );
    });

    test(
      'user-facing widget files do not contain placeholders or corruption markers',
      () {
        final List<String> offenders = <String>[];
        const List<String> badTokens = <String>[
          'TODO',
          'Placeholder',
          'Coming soon',
          'lorem ipsum',
          'corrupt',
          'fixed_fixed',
        ];

        for (final File file in SourceTestUtils.dartFilesUnder('lib')) {
          final String path = SourceTestUtils.normalizePath(
            file.path,
          ).toLowerCase();
          if (!_isWidgetSurfacePath(path) || !_hasWidgetHintInFilename(path)) {
            continue;
          }

          final String text = SourceTestUtils.readText(file);
          if (badTokens.any(text.contains) ||
              text.contains('package:flutter_test')) {
            offenders.add(SourceTestUtils.normalizePath(file.path));
          }
        }

        expect(
          offenders,
          isEmpty,
          reason: 'Widget contract violations detected: $offenders',
        );
      },
    );
  });
}
