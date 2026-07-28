import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String readAllLib() {
    final root = Directory('lib');
    final buffer = StringBuffer();

    if (!root.existsSync()) return '';

    for (final entity in root.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        buffer.writeln(entity.path);
        buffer.writeln(entity.readAsStringSync());
      }
    }

    return buffer.toString();
  }

  test('storage layer has initialization and persistence references', () {
    final lib = readAllLib();

    final hasHive = lib.contains('Hive') || lib.contains('HiveService');
    final hasSharedPrefs = lib.contains('SharedPreferences');
    final hasStorageService = lib.contains('StorageService') || lib.contains('storage');

    expect(
      hasHive || hasSharedPrefs || hasStorageService,
      isTrue,
      reason: 'No obvious persistence layer found in lib.',
    );
  });

  test('tutorial progress persistence is not memory-only', () {
    final repo = File('lib/tutorial/tutorial_repository.dart').existsSync()
        ? File('lib/tutorial/tutorial_repository.dart').readAsStringSync()
        : '';

    expect(repo.contains('saveProgress'), isTrue);
    expect(repo.contains('loadProgress'), isTrue);

    final hasPersistenceBackend =
        repo.contains('SharedPreferences') ||
        repo.contains('Hive') ||
        repo.contains('storage') ||
        repo.contains('jsonEncode') ||
        repo.contains('jsonDecode');

    expect(
      hasPersistenceBackend,
      isTrue,
      reason: 'Tutorial repository does not appear to persist progress through a backend/json mechanism.',
    );
  });

  test('auth code contains session restore or login continuity path', () {
    final lib = readAllLib();

    final hasRestore =
        lib.contains('restoreSession') ||
        lib.contains('currentSession') ||
        lib.contains('refreshSession') ||
        lib.contains('onAuthStateChange') ||
        lib.contains('authStateChanges');

    expect(
      hasRestore,
      isTrue,
      reason: 'No obvious auth session restore path found.',
    );
  });
}
