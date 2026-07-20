import 'package:fantastic_guacamole/data/services/local_user_data_cleanup_service.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'emotion_state_v1': 'focused',
      'user_preferences_json': '{"mode":"pilot"}',
      'onboarding_complete': true,
      'onboarding_content_version': 7,
      'onboarding_step_index': 3,
      'onboarding_state_v1': '{"complete":true}',
      'onboarding_complete_user-1': true,
      'onboarding_content_version_user-1': 7,
      'onboarding_step_index_user-1': 0,
      'onboarding_state_v1_user-1': '{"complete":true}',
    });
  });

  test('clears explicit user-owned local data without deleting the Hive cipher', () async {
    final SecureStore store = SecureStore(backend: InMemorySecureStoreBackend());
    final _RecordingHiveStore hive = _RecordingHiveStore();
    final LocalUserDataCleanupService service = LocalUserDataCleanupService(
      preferences: const SharedPrefsStoreAdapter(),
      hive: hive,
      secureStore: store,
    );

    await store.writeString('auth.cached_session', 'present');
    await store.writeString('chrono_log_entries_v2', 'present');
    await store.writeString('chronospark.hive.cipher.v1', 'preserve-me');

    await service.clear(userId: 'user-1');

    expect(await store.readString('auth.cached_session'), isNull);
    expect(await store.readString('chrono_log_entries_v2'), isNull);
    expect(await store.readString('chronospark.hive.cipher.v1'), 'preserve-me');
    expect(hive.clearedBoxes, contains(HiveBoxes.tasks));
    expect(hive.clearedBoxes, contains(HiveBoxes.goals));
    expect(SharedPrefsService.load('emotion_state_v1'), isNull);
    expect(SharedPrefsService.load('user_preferences_json'), isNull);
    expect(SharedPrefsService.load('onboarding_state_v1'), isNull);
    expect(SharedPrefsService.load('onboarding_state_v1_user-1'), isNull);
  });
}

class _RecordingHiveStore implements HiveStore {
  final List<String> clearedBoxes = <String>[];

  @override
  Box<T> box<T>(String key) {
    throw UnimplementedError();
  }

  @override
  Future<void> clearBox(String key) async {
    clearedBoxes.add(key);
  }

  @override
  Future<void> closeBox(String key) async {}

  @override
  Future<void> init() async {}

  @override
  bool isBoxOpen(String key) => false;

  @override
  Future<Box<T>> openBox<T>(String key) {
    throw UnimplementedError();
  }
}