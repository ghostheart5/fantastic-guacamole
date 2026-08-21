import 'dart:io';

import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/services/local_user_data_cleanup_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'local_user_data_cleanup_test_',
    );
    await Hive.close();
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'inspects an already-open string task box without a Hive type error',
    () async {
      final Box<String> tasks = await Hive.openBox<String>(HiveBoxes.tasks);
      await tasks.put('task-1', '{"id":"task-1"}');
      final LocalUserDataCleanupService service = LocalUserDataCleanupService(
        hive: const _DirectHiveStore(),
        secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
        preferences: _MemoryPreferences(),
        sensitivePreferences: _MemoryPreferences(),
        notifications: NotificationScheduler(),
      );

      expect(await service.hasUnownedAccountData(), isTrue);
      expect(Hive.box<String>(HiveBoxes.tasks).get('task-1'), isNotNull);
    },
  );
}

class _DirectHiveStore implements HiveStore {
  const _DirectHiveStore();

  @override
  Future<void> init() async {}

  @override
  bool isBoxOpen(String key) => Hive.isBoxOpen(key);

  @override
  Future<Box<T>> openBox<T>(String key) {
    if (Hive.isBoxOpen(key)) {
      return Future<Box<T>>.value(Hive.box<T>(key));
    }
    return Hive.openBox<T>(key);
  }

  @override
  Box<T> box<T>(String key) => Hive.box<T>(key);

  @override
  Future<void> clearBox(String key) async {
    final Box<String> target = Hive.isBoxOpen(key)
        ? Hive.box<String>(key)
        : await Hive.openBox<String>(key);
    await target.clear();
  }

  @override
  Future<void> closeBox(String key) async {
    if (Hive.isBoxOpen(key)) await Hive.box<String>(key).close();
  }
}

class _MemoryPreferences implements SharedPrefsStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> init() async {}

  @override
  Future<void> save(String key, String value) async {
    _values[key] = value;
  }

  @override
  String? load(String key) => _values[key];

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> clear() async {
    _values.clear();
  }
}
