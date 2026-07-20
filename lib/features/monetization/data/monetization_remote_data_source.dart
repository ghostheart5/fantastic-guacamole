import 'package:fantastic_guacamole/features/monetization/models/ai_credit_transaction.dart';
import 'package:fantastic_guacamole/features/monetization/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/features/monetization/models/entitlement_event.dart';
import 'package:fantastic_guacamole/features/monetization/models/subscription_status.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class MonetizationBackendException implements Exception {
  const MonetizationBackendException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MonetizationRemoteDataSource {
  const MonetizationRemoteDataSource(this._client);

  final sb.SupabaseClient? _client;

  String? get currentUserId => _client?.auth.currentUser?.id;
  bool get isReady => _client != null && currentUserId != null;

  Future<SubscriptionStatus> fetchSubscriptionStatus() async {
    final sb.SupabaseClient? client = _client;
    final String? userId = currentUserId;
    if (client == null || userId == null) {
      if (client == null) {
        throw const MonetizationBackendException(
          'Supabase monetization backend is unavailable.',
        );
      }
      return SubscriptionStatus.free();
    }
    final dynamic row = await client
        .from('monetization_subscription_statuses')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row is! Map<String, dynamic>) {
      return SubscriptionStatus.free();
    }
    return SubscriptionStatus.fromMap(row);
  }

  Future<AiCreditWallet> fetchWallet() async {
    final sb.SupabaseClient? client = _client;
    final String? userId = currentUserId;
    if (client == null || userId == null) {
      if (client == null) {
        throw const MonetizationBackendException(
          'Supabase monetization backend is unavailable.',
        );
      }
      return AiCreditWallet.free();
    }
    final dynamic row = await client
        .from('monetization_wallets')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row is! Map<String, dynamic>) {
      return AiCreditWallet.free();
    }
    return AiCreditWallet.fromMap(row);
  }

  Future<List<AiCreditTransaction>> fetchTransactions({int limit = 50}) async {
    final sb.SupabaseClient? client = _client;
    final String? userId = currentUserId;
    if (client == null || userId == null) {
      if (client == null) {
        throw const MonetizationBackendException(
          'Supabase monetization backend is unavailable.',
        );
      }
      return const <AiCreditTransaction>[];
    }
    final List<dynamic> rows = await client
        .from('monetization_credit_transactions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows
        .whereType<Map<String, dynamic>>()
        .map(AiCreditTransaction.fromMap)
        .toList(growable: false);
  }

  Future<List<EntitlementEvent>> fetchEntitlementEvents({int limit = 30}) async {
    final sb.SupabaseClient? client = _client;
    final String? userId = currentUserId;
    if (client == null || userId == null) {
      if (client == null) {
        throw const MonetizationBackendException(
          'Supabase monetization backend is unavailable.',
        );
      }
      return const <EntitlementEvent>[];
    }
    final List<dynamic> rows = await client
        .from('monetization_entitlement_events')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows
        .whereType<Map<String, dynamic>>()
        .map(EntitlementEvent.fromMap)
        .toList(growable: false);
  }

  Future<AiCreditWallet> consumeCredits({
    required int amount,
    required String reason,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    if (!isReady) {
      throw const MonetizationBackendException(
        'Authentication is required before consuming credits.',
      );
    }
    final dynamic result = await _client!.rpc<dynamic>(
      'consume_monetization_credits',
      params: <String, dynamic>{
        'credit_amount': amount,
        'reason': reason,
        'metadata': metadata,
      },
    );
    Map<String, dynamic>? row;
    if (result is List && result.isNotEmpty && result.first is Map) {
      row = Map<String, dynamic>.from(result.first as Map);
    } else if (result is Map) {
      row = Map<String, dynamic>.from(result);
    }
    if (row == null) {
      throw const FormatException('Invalid consume credits payload.');
    }
    return AiCreditWallet.fromMap(<String, dynamic>{
      'balance': row['balance'],
      'allowance_remaining': row['allowance_remaining'],
      'bonus_balance': row['bonus_balance'],
      'period_credits': row['period_credits'],
      'lifetime_earned': row['lifetime_earned'],
      'lifetime_spent': row['lifetime_spent'],
      'tier': row['tier'],
      'updated_at': row['updated_at'],
      'period_ends_at': row['period_ends_at'],
    });
  }
}