import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

bool _isWidgetSurfacePath(String path) {
  final normalized = path.replaceAll('\\', '/').toLowerCase();
  final inSurface =
      normalized.contains('/ui/') ||
      normalized.contains('/widgets/') ||
      normalized.contains('/presentation/') ||
      normalized.contains('/app/');
  return inSurface && !normalized.contains('/domain/usecases/');
}

bool _hasWidgetHintInFileName(String path) {
  final String normalized = path.replaceAll('\\', '/').toLowerCase();
  final String fileName = normalized.split('/').last;
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
  List<File> dartFilesUnder(String path) {
    final root = Directory(path);
    if (!root.existsSync()) return <File>[];

    return root
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();
  }

  group('Widget file contracts', () {
    test(
      'files named screen page view panel card button tile overlay define widgets',
      () {
        final suspicious = <String>[];

        final widgetKeywords = <String>[
          'extends StatelessWidget',
          'extends StatefulWidget',
          'extends ConsumerWidget',
          'extends HookWidget',
          'extends ConsumerStatefulWidget',
          'Widget build(',
        ];

        for (final file in dartFilesUnder('lib')) {
          final lowerPath = file.path.toLowerCase();

          if (!_isWidgetSurfacePath(lowerPath) ||
              !_hasWidgetHintInFileName(lowerPath)) {
            continue;
          }

          final text = file.readAsStringSync();
          if (lowerPath.contains('/presentation/') &&
              !text.contains('package:flutter/') &&
              !text.contains('package:flutter_riverpod/')) {
            continue;
          }
          final bool hasFlutterImport =
              text.contains('package:flutter/') ||
              text.contains('package:flutter_riverpod/');
          final bool hasWidgetClassHint =
              text.contains('Widget ') || text.contains('build(BuildContext');
          if (!hasFlutterImport && !hasWidgetClassHint) {
            continue;
          }
          final hasWidgetShape = widgetKeywords.any(text.contains);

          if (!hasWidgetShape) {
            suspicious.add(file.path);
          }
        }

        expect(
          suspicious,
          isEmpty,
          reason:
              'Widget-like files that do not define obvious widgets: $suspicious',
        );
      },
    );

    test('widget files do not contain TODO placeholder UI text', () {
      final offenders = <String>[];

      final badPatterns = <String>[
        'TODO',
        'Placeholder',
        'Coming soon',
        'coming soon',
        'lorem ipsum',
        'Lorem ipsum',
      ];

      for (final file in dartFilesUnder('lib')) {
        final lowerPath = file.path.toLowerCase();

        if (!_isWidgetSurfacePath(lowerPath) ||
            !_hasWidgetHintInFileName(lowerPath)) {
          continue;
        }

        final text = file.readAsStringSync();

        if (badPatterns.any(text.contains)) {
          offenders.add(file.path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'User-facing widget files still contain placeholder/TODO text: $offenders',
      );
    });
  });
}
