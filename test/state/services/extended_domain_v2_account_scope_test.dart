import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/extended_domain_entities.dart';
import 'package:fantastic_guacamole/state/services/extended_domain_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final AccountStorageScope scopeA = AccountStorageScope.authenticated(
    'user-A',
  );
  final AccountStorageScope scopeB = AccountStorageScope.authenticated(
    'user-B',
  );

  group('ExtendedDomain V2 account storage', () {
    test('all 16 families use isolated V2 keys across A to B to A', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final List<_Family> families = _families();
      final ExtendedDomainService a = ExtendedDomainService(
        storageScope: scopeA,
      );
      await a.initialize();
      for (final _Family family in families) {
        await family.save(a, 'A-${family.key}');
      }

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      for (final _Family family in families) {
        expect(
          prefs.getString(_v2(family.key, scopeA)),
          contains('A-${family.key}'),
        );
        expect(prefs.containsKey(family.key), isFalse);
      }

      final ExtendedDomainService b = ExtendedDomainService(
        storageScope: scopeB,
      );
      await b.initialize();
      for (final _Family family in families) {
        expect(family.read(b), isEmpty, reason: family.key);
        await family.save(b, 'B-${family.key}');
      }
      for (final _Family family in families) {
        expect(family.read(a).single.id, 'A-${family.key}');
        expect(family.read(b).single.id, 'B-${family.key}');
        expect(
          prefs.getString(_v2(family.key, scopeB)),
          contains('B-${family.key}'),
        );
      }

      await a.cancelAndDrain();
      final ExtendedDomainService rebuiltA = ExtendedDomainService(
        storageScope: scopeA,
      );
      await rebuiltA.initialize();
      for (final _Family family in families) {
        expect(
          family.read(rebuiltA).single.id,
          'A-${family.key}',
          reason: family.key,
        );
      }
    });

    test('legacy global and V1 keys are preserved and never hydrate', () async {
      final Map<String, Object> initial = <String, Object>{
        for (final String key in ExtendedDomainService.legacyStorageKeys)
          key: '[{"id":"legacy-$key"}]',
        'extended_domain.settings.user_A': '[{"id":"legacy-v1"}]',
      };
      SharedPreferences.setMockInitialValues(initial);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await ExtendedDomainService.migrateLegacyStorage(
        prefs: prefs,
        storageScope: 'user A',
      );
      final ExtendedDomainService service = ExtendedDomainService(
        storageScope: scopeA,
      );
      await service.initialize();
      for (final _Family family in _families()) {
        expect(family.read(service), isEmpty, reason: family.key);
        expect(prefs.getString(family.key), '[{"id":"legacy-${family.key}"}]');
      }
      expect(
        prefs.getString('extended_domain.settings.user_A'),
        '[{"id":"legacy-v1"}]',
      );
    });

    test(
      'unsafe and signed-out scopes fail closed without a fallback',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'extended_domain.coach_messages': '[{"id":"legacy"}]',
        });
        for (final AccountStorageScope scope in <AccountStorageScope>[
          const AccountStorageScope.unsafe(),
          const AccountStorageScope.signedOut(),
        ]) {
          final ExtendedDomainService service = ExtendedDomainService(
            storageScope: scope,
          );
          await service.initialize();
          await service.saveCoachMessage(
            const CoachMessage(id: 'must-not-write'),
          );
          expect(service.getCoachMessages(), isEmpty);
        }
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('extended_domain.coach_messages'),
          '[{"id":"legacy"}]',
        );
      },
    );
  });
}

String _v2(String key, AccountStorageScope scope) =>
    ExtendedDomainService.canonicalStorageKeyForScope(key, scope);

class _Family {
  const _Family(this.key, this.save, this.read);
  final String key;
  final Future<void> Function(ExtendedDomainService service, String id) save;
  final List<LightweightEntity> Function(ExtendedDomainService service) read;
}

List<_Family> _families() => <_Family>[
  _Family(
    'extended_domain.coach_messages',
    (s, id) => s.saveCoachMessage(CoachMessage(id: id)),
    (s) => s.getCoachMessages(),
  ),
  _Family(
    'extended_domain.si_queries',
    (s, id) => s.saveSiQuery(SiQuery(id: id)),
    (s) => s.getSiQueries(),
  ),
  _Family(
    'extended_domain.user_intents',
    (s, id) => s.saveUserIntent(UserIntent(id: id)),
    (s) => s.getUserIntents(),
  ),
  _Family(
    'extended_domain.journal_entries',
    (s, id) => s.saveJournalEntry(JournalEntry(id: id)),
    (s) => s.getJournalEntries(),
  ),
  _Family(
    'extended_domain.analytics_metrics',
    (s, id) => s.saveAnalyticsMetric(AnalyticsMetric(id: id)),
    (s) => s.getAnalyticsMetrics(),
  ),
  _Family(
    'extended_domain.app_notifications',
    (s, id) => s.saveAppNotification(AppNotification(id: id)),
    (s) => s.getAppNotifications(),
  ),
  _Family(
    'extended_domain.rewards',
    (s, id) => s.saveReward(Reward(id: id)),
    (s) => s.getRewards(),
  ),
  _Family(
    'extended_domain.themes',
    (s, id) => s.saveAppTheme(AppTheme(id: id)),
    (s) => s.getThemes(),
  ),
  _Family(
    'extended_domain.settings',
    (s, id) => s.saveAppSetting(AppSetting(id: id)),
    (s) => s.getSettings(),
  ),
  _Family(
    'extended_domain.sync_states',
    (s, id) => s.saveSyncState(SyncState(id: id)),
    (s) => s.getSyncStates(),
  ),
  _Family(
    'extended_domain.offline_states',
    (s, id) => s.saveOfflineState(OfflineState(id: id)),
    (s) => s.getOfflineStates(),
  ),
  _Family(
    'extended_domain.app_errors',
    (s, id) => s.saveAppError(AppError(id: id)),
    (s) => s.getAppErrors(),
  ),
  _Family(
    'extended_domain.recovery_states',
    (s, id) => s.saveRecoveryState(RecoveryState(id: id)),
    (s) => s.getRecoveryStates(),
  ),
  _Family(
    'extended_domain.subscription_plans',
    (s, id) => s.saveSubscriptionPlan(SubscriptionPlanEntity(id: id)),
    (s) => s.getSubscriptionPlans(),
  ),
  _Family(
    'extended_domain.privacy_policies',
    (s, id) => s.savePrivacyPolicy(PrivacyPolicy(id: id)),
    (s) => s.getPrivacyPolicies(),
  ),
  _Family(
    'extended_domain.health_checks',
    (s, id) => s.saveHealthCheck(HealthCheckResult(id: id)),
    (s) => s.getHealthChecks(),
  ),
];
