import 'package:fantastic_guacamole/data/models/notification_record.dart';
import 'package:fantastic_guacamole/state/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/state/models/experiment_assignment.dart';
import 'package:fantastic_guacamole/state/models/kill_switch_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('model integrity', () {
    test('kill switches do not retain a caller-mutable set', () {
      final Set<String> disabled = <String>{'planner'};
      final KillSwitchRegistry registry = KillSwitchRegistry(
        disabledCapabilities: disabled,
      );

      disabled.add('timeline');

      expect(registry.isDisabled('planner'), isTrue);
      expect(registry.isDisabled('timeline'), isFalse);
      expect(
        () => registry.disabledCapabilities.add('timeline'),
        throwsUnsupportedError,
      );
    });

    test('rejects malformed notification records', () {
      expect(
        () => NotificationRecord.fromJson(<String, dynamic>{
          'id': 'notification-1',
          'title': '',
          'message': 'Reminder',
          'scheduledAt': '2026-08-29T12:00:00.000Z',
          'isEnabled': true,
          'isRead': false,
        }),
        throwsFormatException,
      );
      expect(
        () => NotificationRecord.fromJson(<String, dynamic>{
          'id': 'notification-1',
          'title': 'Reminder',
          'message': 'Take a break',
          'scheduledAt': '2026-08-29T12:00:00.000Z',
          'isEnabled': 'true',
          'isRead': false,
        }),
        throwsFormatException,
      );
    });

    test('rejects malformed AI credit wallets', () {
      expect(
        () => AiCreditWallet.fromJson(<String, dynamic>{
          'balance': 21,
          'tier': 'free',
          'allowance': 20,
          'resetAt': '2026-08-30T12:00:00.000Z',
          'updatedAt': '2026-08-29T12:00:00.000Z',
        }),
        throwsFormatException,
      );
    });

    test('derives control status from the selected variant', () {
      final ExperimentAssignment assignment =
          ExperimentAssignment.fromJson(<String, Object?>{
            'experimentId': 'planner-copy',
            'variant': 'control',
            'bucket': 0,
            'isControl': false,
          });

      expect(assignment.isControl, isTrue);
    });
  });
}
