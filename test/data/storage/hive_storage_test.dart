import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/sensitive_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async => '/tmp/app_docs';

  @override
  Future<String?> getApplicationSupportPath() async => '/tmp/app_support';

  @override
  Future<String?> getTemporaryPath() async => '/tmp/app_temp';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PathProviderPlatform.instance = _MockPathProviderPlatform();
  });

  group('HiveService', () {
    test('critical box names are valid and encrypted set is consistent', () {
      expect(HiveBoxes.tasks, isNotEmpty);
      expect(HiveBoxes.goals, isNotEmpty);
      expect(HiveBoxes.progression, isNotEmpty);
      expect(HiveBoxes.encryptedBoxes.contains(HiveBoxes.tasks), isTrue);
    });

    test('secure store wrapper round-trips values', () async {
      final store = SecureStore(backend: InMemorySecureStoreBackend());
      await store.writeString('key', 'value');
      expect(await store.readString('key'), 'value');
      await store.delete('key');
      expect(await store.readString('key'), isNull);
    });

    test('init can complete without warming every box', () async {
      await expectLater(HiveService.init(warmupBoxes: false), completes);
    });

    test('sensitive prefs init completes even if secure storage is unavailable', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await expectLater(SensitivePrefsStore.instance.init(), completes);
      expect(SensitivePrefsStore.instance.load('missing_key'), isNull);
    });
  });
}
