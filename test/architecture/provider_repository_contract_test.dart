import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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

  String readAllUnder(String path) {
    final buffer = StringBuffer();

    for (final file in dartFilesUnder(path)) {
      buffer.writeln(file.path);
      buffer.writeln(file.readAsStringSync());
    }

    return buffer.toString();
  }

  test('provider files should contain real provider declarations', () {
    final files = dartFilesUnder('lib')
        .where((file) {
          final String path = file.path.toLowerCase().replaceAll('\\', '/');
          if (!path.contains('provider')) {
            return false;
          }
          if (path.endsWith('/providers.dart') || path.endsWith('_guards.dart')) {
            return false;
          }
          if (path.contains('/domain/usecases/')) {
            return false;
          }
          return true;
        })
        .toList();

    final suspicious = <String>[];

    for (final file in files) {
      final text = file.readAsStringSync();

      final hasProvider =
          text.contains('Provider<') ||
          text.contains('StateNotifierProvider') ||
          text.contains('NotifierProvider') ||
          text.contains('AsyncNotifierProvider') ||
          text.contains('ChangeNotifierProvider') ||
          text.contains('StreamProvider') ||
          text.contains('FutureProvider');

      if (!hasProvider) {
        suspicious.add(file.path);
      }
    }

    expect(
      suspicious,
      isEmpty,
      reason: 'Files named provider do not appear to declare providers: $suspicious',
    );
  });

  test('repository files should expose load save fetch create update or delete behavior', () {
    final files = dartFilesUnder('lib')
        .where((file) {
          final String path = file.path.toLowerCase().replaceAll('\\', '/');
          if (!path.contains('repository')) {
            return false;
          }
          if (path.contains('/domain/interfaces/')) {
            return false;
          }
          return true;
        })
        .toList();

    final suspicious = <String>[];

    for (final file in files) {
      final text = file.readAsStringSync().toLowerCase();

      final hasRepoBehavior =
          text.contains('load') ||
          text.contains('save') ||
          text.contains('fetch') ||
          text.contains('create') ||
          text.contains('update') ||
          text.contains('delete') ||
          text.contains('watch') ||
          text.contains('stream') ||
          text.contains('remove') ||
          text.contains('clear') ||
          text.contains('reset') ||
          text.contains('get') ||
          text.contains('check') ||
          text.contains('start') ||
          text.contains('cancel') ||
          text.contains('restore');

      if (!hasRepoBehavior) {
        suspicious.add(file.path);
      }
    }

    expect(
      suspicious,
      isEmpty,
      reason: 'Repository files missing obvious repository behavior: $suspicious',
    );
  });

  test('controllers should expose action methods and not be empty shells', () {
    final files = dartFilesUnder('lib')
        .where((file) {
          final String path = file.path.toLowerCase().replaceAll('\\', '/');
          if (!path.contains('controller')) {
            return false;
          }
          if (path.endsWith('/controllers.dart')) {
            return false;
          }
          return true;
        })
        .toList();

    final suspicious = <String>[];

    for (final file in files) {
      final text = file.readAsStringSync();
      final bool declaresControllerClass =
          text.contains('class ') && text.toLowerCase().contains('controller');
      if (!declaresControllerClass) {
        continue;
      }

        final methodLikeCount = RegExp(r'\b(?:Future<[^>]+>|void|bool|int|String|double|[A-Z][A-Za-z0-9_<>, ?]*)\s+[a-zA-Z_]\w*\s*\(')
          .allMatches(text)
          .length;

      if (methodLikeCount < 1) {
        suspicious.add(file.path);
      }
    }

    expect(
      suspicious,
      isEmpty,
      reason: 'Controller files look like empty shells: $suspicious',
    );
  });

  test('backup architecture files are not imported anywhere', () {
    final lib = readAllUnder('lib');

    expect(lib.contains('.bak_arch_fix'), isFalse);
    expect(lib.contains('.bak_arch_wording'), isFalse);
    expect(lib.contains("import '.bak"), isFalse);
    expect(lib.contains('import ".bak'), isFalse);
  });
}
