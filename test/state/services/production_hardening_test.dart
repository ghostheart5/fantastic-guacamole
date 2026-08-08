import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
import 'package:fantastic_guacamole/domain/policies/notification_policy.dart';
import 'package:fantastic_guacamole/domain/policies/si_policy.dart';
import 'package:fantastic_guacamole/state/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/state/services/credit_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for the production-hardening pass:
/// - in-app notifications must never become OS notifications
/// - AI credits must come back when no response was delivered
/// - model output must meet the same claim policy as SI decisions
void main() {
  group('in-app notifications are not OS notifications', () {
    test('a disabled entity is never schedulable', () {
      final NotificationEntity inApp = NotificationEntity(
        id: 'notification-1',
        title: 'Completion',
        message: 'Task completed.',
        scheduledAt: DateTime.now().add(const Duration(seconds: 1)),
        isEnabled: false,
      );

      // NotificationScheduler.schedule short-circuits on !isEnabled, and the
      // domain policy agrees. Both gates must hold for the in-app path to be
      // safe from producing a system notification.
      expect(inApp.isEnabled, isFalse);
      expect(NotificationPolicy.canSchedule(inApp), isFalse);
    });

    test('a real reminder stays enabled and future-dated', () {
      final NotificationEntity reminder = NotificationEntity(
        id: 'goal_reminder_1',
        title: 'Goal reminder',
        message: 'Time to work on your goal.',
        scheduledAt: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(reminder.isEnabled, isTrue);
      expect(NotificationPolicy.canSchedule(reminder), isTrue);
    });
  });

  group('CreditService.refund', () {
    late CreditService service;

    setUp(() {
      service = CreditService(prefs: _FakePrefs());
    });

    test('returns credits taken by a spend that produced nothing', () async {
      final AiCreditWallet before = await service.loadWallet(premium: false);
      final AiCreditSpendResult spend = await service.spend(
        premium: false,
        amount: 3,
      );
      expect(spend.allowed, isTrue);
      expect(spend.wallet.balance, before.balance - 3);

      final AiCreditWallet after = await service.refund(
        premium: false,
        amount: 3,
      );
      expect(after.balance, before.balance);
    });

    test('cannot exceed the allowance, so it cannot mint credits', () async {
      await service.refund(premium: false, amount: 999);
      final AiCreditWallet after = await service.loadWallet(premium: false);

      expect(after.balance, after.allowance);
      expect(after.balance, lessThanOrEqualTo(after.allowance));
    });

    test('a zero or negative refund is a no-op', () async {
      final AiCreditWallet before = await service.loadWallet(premium: false);

      await service.refund(premium: false, amount: 0);
      await service.refund(premium: false, amount: -5);
      final AiCreditWallet after = await service.loadWallet(premium: false);

      expect(after.balance, before.balance);
    });

    test('spend then refund is balance-neutral across repeats', () async {
      final AiCreditWallet before = await service.loadWallet(premium: false);
      for (int i = 0; i < 5; i++) {
        await service.spend(premium: false, amount: 2);
        await service.refund(premium: false, amount: 2);
      }
      final AiCreditWallet after = await service.loadWallet(premium: false);
      expect(after.balance, before.balance);
    });
  });

  group('SiPolicy.containsUnsupportedClaim covers free-form text', () {
    test('flags every blocked claim', () {
      for (final String claim in <String>[
        'guarantee',
        'cure',
        'diagnose',
        'prescribe',
        'legal advice',
      ]) {
        expect(
          SiPolicy.containsUnsupportedClaim('This will $claim your problem.'),
          isTrue,
          reason: 'claim "$claim" must be flagged in assistant prose',
        );
      }
    });

    test('is case-insensitive', () {
      expect(SiPolicy.containsUnsupportedClaim('I GUARANTEE results'), isTrue);
    });

    test('passes ordinary coaching text', () {
      expect(
        SiPolicy.containsUnsupportedClaim(
          'Focus on the spec for 25 minutes, then take a break.',
        ),
        isFalse,
      );
    });

    test('decision behaviour is unchanged by the extraction', () {
      expect(
        SiPolicy.isSupportedAndSafe(
          const SiDecisionEntity(rationale: 'I guarantee this works'),
        ),
        isFalse,
      );
      expect(
        SiPolicy.isSupportedAndSafe(
          const SiDecisionEntity(rationale: 'Highest priority task selected.'),
        ),
        isTrue,
      );
    });
  });
}

class _FakePrefs implements SharedPrefsStore {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => _store[key];

  @override
  Future<void> save(String key, String value) async => _store[key] = value;

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> clear() async => _store.clear();
}
