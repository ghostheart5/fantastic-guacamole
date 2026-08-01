import 'package:fantastic_guacamole/features/monetization/integration/monetization_actions_compat.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/supabase_backend_provider.dart';
import 'package:fantastic_guacamole/state/services/app_integration_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('si pipeline integration snapshot banner', () {
    test('formats a compact integration banner', () {
      const AppIntegrationSnapshot snapshot = _healthySnapshot;

      final String banner = buildIntegrationSurfaceSnapshot(snapshot);

      expect(
        banner,
        'USER user_a · SUPABASE HEALTHY · SYNC OK · Q 2 · MONO LEGACY',
      );
    });

    test('falls back cleanly for anonymous and warning states', () {
      const AppIntegrationSnapshot snapshot = _warningSnapshot;

      final String banner = buildIntegrationSurfaceSnapshot(snapshot);

      expect(
        banner,
        'ANON · SUPABASE CONNECTIVITY ISSUE · SYNC WARN · Q 0 · MONO FEATURE',
      );
    });
  });
}

const AppIntegrationSnapshot _healthySnapshot = AppIntegrationSnapshot(
  currentUserId: 'user_abcdef123456',
  supabaseHealth: SupabaseBackendHealth(
    configured: true,
    initialized: true,
    authenticated: true,
    databaseReachable: true,
    storageReachable: true,
    realtimeConfigured: true,
    badge: SupabaseHealthBadge.healthy,
    message: 'ok',
  ),
  syncErrorMessage: null,
  offlineQueueCount: 2,
  monetizationStatus: MonetizationStatusSnapshot(
    planId: 'premium_monthly',
    isPremium: true,
    isActive: true,
    walletBalance: 120,
    stackType: MonetizationStackType.legacy,
  ),
);

const AppIntegrationSnapshot _warningSnapshot = AppIntegrationSnapshot(
  currentUserId: null,
  supabaseHealth: SupabaseBackendHealth(
    configured: false,
    initialized: false,
    authenticated: false,
    databaseReachable: false,
    storageReachable: false,
    realtimeConfigured: false,
    badge: SupabaseHealthBadge.connectivityIssue,
    message: 'missing config',
  ),
  syncErrorMessage: 'queued',
  offlineQueueCount: 0,
  monetizationStatus: MonetizationStatusSnapshot(
    planId: '__none__',
    isPremium: false,
    isActive: false,
    walletBalance: 0,
    stackType: MonetizationStackType.feature,
  ),
);
