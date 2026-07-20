import 'package:fantastic_guacamole/features/monetization/data/models/models.dart';
import 'package:fantastic_guacamole/features/monetization/data/monetization_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

abstract class SubscriptionRepository {
  Future<List<SubscriptionPlan>> getSubscriptionPlans();
  Future<UserSubscription?> getCurrentSubscription();
}

class SupabaseSubscriptionRepository implements SubscriptionRepository {
  SupabaseSubscriptionRepository(this._client);

  final sb.SupabaseClient? _client;

  static const List<String> _planTables = <String>[
    'subscription_plans',
    'monetization_subscription_plans',
  ];
  static const List<String> _subscriptionTables = <String>[
    'subscriptions',
    'monetization_subscription_statuses',
  ];

  @override
  Future<List<SubscriptionPlan>> getSubscriptionPlans() async {
    final sb.SupabaseClient? client = _client;
    if (client == null) {
      throw const MonetizationBackendException(
        'Supabase monetization backend is unavailable.',
      );
    }

    Object? lastError;
    for (final String table in _planTables) {
      try {
        final List<dynamic> rows = await client
            .from(table)
            .select()
            .eq('is_active', true)
            .order('price_micros', ascending: true);
        return rows
            .whereType<Map<String, dynamic>>()
            .map(SubscriptionPlan.fromJson)
            .toList(growable: false);
      } on Object catch (error) {
        lastError = error;
        // Try the next table alias.
      }
    }
    throw MonetizationBackendException(
      'Subscription plans could not be loaded from Supabase: ${lastError ?? 'unknown error'}',
    );
  }

  @override
  Future<UserSubscription?> getCurrentSubscription() async {
    final sb.SupabaseClient? client = _client;
    if (client == null) {
      throw const MonetizationBackendException(
        'Supabase monetization backend is unavailable.',
      );
    }
    final String? userId = client.auth.currentUser?.id;
    if (userId == null) return null;

    Object? lastError;
    for (final String table in _subscriptionTables) {
      try {
        final dynamic row = await client
            .from(table)
            .select()
            .eq('user_id', userId)
            .maybeSingle();
        if (row is Map<String, dynamic>) {
          return UserSubscription.fromJson(row);
        }
      } on Object catch (error) {
        lastError = error;
        // Try the next table alias.
      }
    }
    if (lastError != null) {
      throw MonetizationBackendException(
        'Subscription status could not be loaded from Supabase: $lastError',
      );
    }
    return null;
  }
}
