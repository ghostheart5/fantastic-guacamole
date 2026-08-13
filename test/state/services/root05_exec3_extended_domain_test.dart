import 'package:fantastic_guacamole/domain/entities/extended_domain_entities.dart';
import 'package:fantastic_guacamole/state/services/extended_domain_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('T15 EXT-H01 drains writes without deleting durable state', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ExtendedDomainService service = ExtendedDomainService();
    await service.initialize();
    await service.saveCoachMessage(const CoachMessage(id: 'message'));
    await service.cancelAndDrain();
    await service.cancelAndDrain();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('extended_domain.coach_messages'),
      contains('message'),
    );
    expect(service.getCoachMessages(), isEmpty);
  });
}
