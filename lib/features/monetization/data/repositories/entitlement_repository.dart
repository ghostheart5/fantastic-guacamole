import 'package:fantastic_guacamole/features/monetization/data/models/models.dart';
import 'package:fantastic_guacamole/features/monetization/data/monetization_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

abstract class EntitlementRepository {
  Future<PremiumEntitlement> getPremiumEntitlement();
  Future<List<EntitlementEvent>> getEntitlementEvents({int limit = 30});
}

class SupabaseEntitlementRepository implements EntitlementRepository {
  SupabaseEntitlementRepository(this._client);

  final sb.SupabaseClient? _client;

  static const List<String> _eventTables = <String>[
    'entitlement_events',
    'monetization_entitlement_events',
  ];
  static const List<String> _subscriptionTables = <String>[
    'subscriptions',
    'monetization_subscription_statuses',
  ];

  @override
  Future<List<EntitlementEvent>> getEntitlementEvents({int limit = 30}) async {
    final sb.SupabaseClient? client = _client;
    if (client == null) {
      throw const MonetizationBackendException(
        'Supabase monetization backend is unavailable.',
      );
    }
    final String? userId = client.auth.currentUser?.id;
    if (userId == null) return const <EntitlementEvent>[];

    Object? lastError;
    for (final String table in _eventTables) {
      try {
        final List<dynamic> rows = await client
            .from(table)
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(limit);
        return rows
            .whereType<Map<String, dynamic>>()
            .map(EntitlementEvent.fromJson)
            .toList(growable: false);
      } on Object catch (error) {
        lastError = error;
      }
    }

    throw MonetizationBackendException(
      'Entitlement events could not be loaded from Supabase: ${lastError ?? 'unknown error'}',
    );
  }

  @override
  Future<PremiumEntitlement> getPremiumEntitlement() async {
    final sb.SupabaseClient? client = _client;
    if (client == null) {
      throw const MonetizationBackendException(
        'Supabase monetization backend is unavailable.',
      );
    }
    if (client.auth.currentUser == null) {
      return const PremiumEntitlement(
        isPremium: false,
        isActive: false,
        planId: 'free',
        source: 'local',
      );
    }

    final String userId = client.auth.currentUser!.id;
    Object? lastError;
    for (final String table in _subscriptionTables) {
      try {
        final dynamic row = await client
            .from(table)
            .select()
            .eq('user_id', userId)
            .maybeSingle();
        if (row is Map<String, dynamic>) {
          final String planId = row['plan_id']?.toString() ?? 'free';
          final bool isActive = row['is_active'] == true;
          final bool isPremium = isActive && planId != 'free';
          return PremiumEntitlement(
            isPremium: isPremium,
            isActive: isActive,
            planId: planId,
            source: row['source']?.toString() ?? 'supabase',
            expiresAt: _parseDateTime(row['expires_at']),
            status: row['status']?.toString(),
          );
        }
      } on Object catch (error) {
        lastError = error;
      }
    }

    if (lastError != null) {
      throw MonetizationBackendException(
        'Premium entitlement could not be loaded from Supabase: $lastError',
      );
    }
    return const PremiumEntitlement(
      isPremium: false,
      isActive: false,
      planId: 'free',
      source: 'supabase',
    );
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
