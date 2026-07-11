import 'package:fantastic_guacamole/data/services/remote_config_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns seeded defaults without firebase runtime', () async {
    final service = RemoteConfigService(
      initialValues: const <String, Object?>{
        'flag_tutorial_enabled': true,
        'exp_sample': 'control',
      },
    );

    await service.refresh();

    expect(service.getBool('flag_tutorial_enabled'), isTrue);
    expect(service.getString('exp_sample'), 'control');
  });

  test('applySnapshot overrides values for local runtime usage', () async {
    final service = RemoteConfigService(
      initialValues: const <String, Object?>{'flag_a': false},
    );

    service.applySnapshot(<String, Object?>{'flag_a': true, 'bucket_demo': 7});

    expect(service.getBool('flag_a'), isTrue);
    expect(service.getInt('bucket_demo'), 7);
  });
}
