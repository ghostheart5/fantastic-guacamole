import 'package:fantastic_guacamole/domain/entities/extended_domain_entities.dart';
import 'package:fantastic_guacamole/state/services/extended_domain_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'fails closed on malformed local records and persists used records',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'extended_domain.planner_messages': '[{"id": 7}]',
      });

      final ExtendedDomainService service = ExtendedDomainService();
      await Future.wait<void>(<Future<void>>[
        service.initialize(),
        service.initialize(),
      ]);

      expect(service.getPlannerMessages(), isEmpty);

      await service.savePlannerMessage(
        const PlannerMessage(id: 'planner-message-1', label: 'Ready'),
      );

      final ExtendedDomainService restored = ExtendedDomainService();
      await restored.initialize();

      expect(restored.getPlannerMessages().single.id, 'planner-message-1');
    },
  );
}
