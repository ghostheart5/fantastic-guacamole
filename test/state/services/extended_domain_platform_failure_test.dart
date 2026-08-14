import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/extended_domain_entities.dart';
import 'package:fantastic_guacamole/state/services/extended_domain_service.dart';
import '../../helpers/controllable_shared_preferences_platform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  late SharedPreferencesStorePlatform original;
  late ControllableSharedPreferencesPlatform platform;

  setUp(() {
    original = SharedPreferencesStorePlatform.instance;
    platform = ControllableSharedPreferencesPlatform();
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = platform;
  });
  tearDown(() {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = original;
  });

  test('platform is controllable and SharedPreferences cache resets', () async {
    platform.values['flutter.value'] = 'A';
    expect((await SharedPreferences.getInstance()).getString('value'), 'A');
    SharedPreferences.resetStatic();
    platform.values['flutter.value'] = 'B';
    expect((await SharedPreferences.getInstance()).getString('value'), 'B');
    await (await SharedPreferences.getInstance()).setString('write', 'ok');
    expect(platform.values['flutter.write'], 'ok');
    await (await SharedPreferences.getInstance()).remove('write');
    expect(platform.values.containsKey('flutter.write'), isFalse);
  });

  test('real ExtendedDomain hydration fails and retries without legacy fallback', () async {
    platform.values['flutter.extended_domain.si_queries'] = '[{"id":"legacy"}]';
    platform.failGetAll = true;
    final ExtendedDomainService failed = ExtendedDomainService(storageScope: AccountStorageScope.authenticated('B'));
    await expectLater(failed.initialize(), throwsStateError);
    platform.failGetAll = false;
    SharedPreferences.resetStatic();
    final ExtendedDomainService recovered = ExtendedDomainService(storageScope: AccountStorageScope.authenticated('B'));
    await recovered.initialize();
    expect(recovered.getSiQueries(), isEmpty);
    expect(platform.values['flutter.extended_domain.si_queries'], '[{"id":"legacy"}]');
  });

  test('real B write failure retries without mutating A or legacy keys', () async {
    platform.values['flutter.extended_domain.si_queries.v2.QQ=='] = '[{"id":"A"}]';
    platform.values['flutter.extended_domain.si_queries'] = '[{"id":"legacy"}]';
    final ExtendedDomainService service = ExtendedDomainService(storageScope: AccountStorageScope.authenticated('B'));
    await service.initialize();
    await service.saveSiQuery(const SiQuery(id: 'B_OK'));
    final Map<String, Object> before = Map<String, Object>.from(platform.values);
    platform.failSetValue = true;
    final int calls = platform.setValueCalls;
    await expectLater(service.saveSiQuery(const SiQuery(id: 'B_RETRY')), throwsStateError);
    expect(platform.setValueCalls, greaterThan(calls));
    expect(platform.values['flutter.extended_domain.si_queries.v2.QQ=='], before['flutter.extended_domain.si_queries.v2.QQ==']);
    expect(platform.values['flutter.extended_domain.si_queries'], before['flutter.extended_domain.si_queries']);
    platform.failSetValue = false;
    await service.saveSiQuery(const SiQuery(id: 'B_RETRY'));
    expect(platform.values.values.join(), contains('B_RETRY'));
  });
}
