import 'dart:io';

import 'package:fantastic_guacamole/data/storage/storage_keys.dart';
import 'package:fantastic_guacamole/data/storage/storage_migration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('storage_migration_test_');
    await Hive.close();
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('old schema migrates to current schema', () async {
    final settings = await Hive.openBox<dynamic>(StorageKeys.settings);
    await settings.put(StorageKeys.storageVersion, 0);

    await StorageMigration.run();

    final theme = await Hive.openBox<dynamic>(StorageKeys.theme);
    expect(
      settings.get(StorageKeys.storageVersion),
      StorageMigration.latestVersion,
    );
    expect(theme.get('current_theme'), 'default');
  });

  test('malformed snapshot returns safe fallback', () async {
    final settings = await Hive.openBox<dynamic>(StorageKeys.settings);
    await settings.put(StorageKeys.storageVersion, 'not-a-number');

    await StorageMigration.run();

    expect(
      settings.get(StorageKeys.storageVersion),
      StorageMigration.latestVersion,
    );
  });

  test('missing keys do not crash', () async {
    await Hive.openBox<dynamic>(StorageKeys.settings);

    await StorageMigration.run();

    final settings = await Hive.openBox<dynamic>(StorageKeys.settings);
    expect(
      settings.get(StorageKeys.storageVersion),
      StorageMigration.latestVersion,
    );
  });

  test('unknown future version does not destroy data', () async {
    final settings = await Hive.openBox<dynamic>(StorageKeys.settings);
    final notifications = await Hive.openBox<dynamic>(
      StorageKeys.notifications,
    );
    await settings.put(
      StorageKeys.storageVersion,
      StorageMigration.latestVersion + 9,
    );
    await notifications.put('n1', 'keep-this');

    await StorageMigration.run();

    expect(
      settings.get(StorageKeys.storageVersion),
      StorageMigration.latestVersion + 9,
    );
    expect(notifications.get('n1'), 'keep-this');
  });

  test(
    'migration preserves tasks logs settings and subscription state',
    () async {
      final settings = await Hive.openBox<dynamic>(StorageKeys.settings);
      final tasks = await Hive.openBox<dynamic>('tasks_box');
      final logs = await Hive.openBox<dynamic>('logs_box');
      final subscription = await Hive.openBox<dynamic>(StorageKeys.session);
      await settings.put(StorageKeys.storageVersion, 0);
      await settings.put('preferred_locale', 'en_US');
      await tasks.put('task-1', '{"id":"task-1"}');
      await logs.put('log-1', '{"id":"log-1"}');
      await subscription.put('subscription', '{"active":true}');

      await StorageMigration.run();

      expect(tasks.get('task-1'), '{"id":"task-1"}');
      expect(logs.get('log-1'), '{"id":"log-1"}');
      expect(settings.get('preferred_locale'), 'en_US');
      expect(subscription.get('subscription'), '{"active":true}');
    },
  );
}
