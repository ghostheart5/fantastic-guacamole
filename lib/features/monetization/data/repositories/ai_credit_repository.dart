import 'package:fantastic_guacamole/features/monetization/data/models/models.dart';
import 'package:fantastic_guacamole/features/monetization/data/monetization_remote_data_source.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

abstract class AiCreditRepository {
  Future<List<AiCreditPackage>> getCreditPackages();
  Future<AiCreditWallet?> getWallet();
  Future<List<AiCreditTransaction>> getTransactions({int limit = 50});
  Future<List<AiCreditPurchase>> getPurchaseHistory({int limit = 50});
  Future<AiCreditWallet?> consumeCredits({
    required int amount,
    required String reason,
    Map<String, dynamic> metadata,
  });
}

class SupabaseAiCreditRepository implements AiCreditRepository {
  SupabaseAiCreditRepository(this._client);

  final sb.SupabaseClient? _client;

  static const List<String> _packageTables = <String>[
    'monetization_credit_packages',
    'ai_credit_packages',
  ];
  static const List<String> _walletTables = <String>[
    'monetization_wallets',
    'ai_credit_wallets',
  ];
  static const List<String> _transactionTables = <String>[
    'monetization_credit_transactions',
    'ai_credit_transactions',
  ];
  static const List<String> _purchaseTables = <String>[
    'monetization_purchases',
    'ai_credit_purchases',
  ];
  static final Set<String> _loggedFallbackTables = <String>{};

  @override
  Future<List<AiCreditPackage>> getCreditPackages() async {
    final sb.SupabaseClient? client = _client;
    if (client == null) {
      throw const MonetizationBackendException(
        'Supabase monetization backend is unavailable.',
      );
    }
    Object? lastError;
    for (int index = 0; index < _packageTables.length; index++) {
      final String table = _packageTables[index];
      try {
        final List<dynamic> rows = await client
            .from(table)
            .select()
            .eq('is_active', true)
            .order('credits', ascending: true);
        _logFallbackIfUsed(
          canonicalTable: _packageTables.first,
          selectedTable: table,
          selectedIndex: index,
        );
        return rows
            .whereType<Map<String, dynamic>>()
            .map(AiCreditPackage.fromJson)
            .toList(growable: false);
      } on Object catch (error) {
        lastError = error;
      }
    }
    throw MonetizationBackendException(
      'Credit packages could not be loaded from Supabase: ${lastError ?? 'unknown error'}',
    );
  }

  @override
  Future<AiCreditWallet?> getWallet() async {
    final sb.SupabaseClient? client = _client;
    if (client == null) {
      throw const MonetizationBackendException(
        'Supabase monetization backend is unavailable.',
      );
    }
    final String? userId = client.auth.currentUser?.id;
    if (userId == null) return null;

    Object? lastError;
    for (int index = 0; index < _walletTables.length; index++) {
      final String table = _walletTables[index];
      try {
        final dynamic row = await client
            .from(table)
            .select()
            .eq('user_id', userId)
            .maybeSingle();
        if (row is Map<String, dynamic>) {
          _logFallbackIfUsed(
            canonicalTable: _walletTables.first,
            selectedTable: table,
            selectedIndex: index,
          );
          return AiCreditWallet.fromJson(row);
        }
      } on Object catch (error) {
        lastError = error;
      }
    }
    if (lastError != null) {
      throw MonetizationBackendException(
        'Wallet could not be loaded from Supabase: $lastError',
      );
    }
    return null;
  }

  @override
  Future<List<AiCreditTransaction>> getTransactions({int limit = 50}) async {
    final sb.SupabaseClient? client = _client;
    if (client == null) {
      throw const MonetizationBackendException(
        'Supabase monetization backend is unavailable.',
      );
    }
    final String? userId = client.auth.currentUser?.id;
    if (userId == null) return const <AiCreditTransaction>[];

    Object? lastError;
    for (int index = 0; index < _transactionTables.length; index++) {
      final String table = _transactionTables[index];
      try {
        final List<dynamic> rows = await client
            .from(table)
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(limit);
        _logFallbackIfUsed(
          canonicalTable: _transactionTables.first,
          selectedTable: table,
          selectedIndex: index,
        );
        return rows
            .whereType<Map<String, dynamic>>()
            .map(AiCreditTransaction.fromJson)
            .toList(growable: false);
      } on Object catch (error) {
        lastError = error;
      }
    }
    throw MonetizationBackendException(
      'Credit history could not be loaded from Supabase: ${lastError ?? 'unknown error'}',
    );
  }

  @override
  Future<List<AiCreditPurchase>> getPurchaseHistory({int limit = 50}) async {
    final sb.SupabaseClient? client = _client;
    if (client == null) {
      throw const MonetizationBackendException(
        'Supabase monetization backend is unavailable.',
      );
    }
    final String? userId = client.auth.currentUser?.id;
    if (userId == null) return const <AiCreditPurchase>[];

    Object? lastError;
    for (int index = 0; index < _purchaseTables.length; index++) {
      final String table = _purchaseTables[index];
      try {
        final List<dynamic> rows = await client
            .from(table)
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(limit);
        _logFallbackIfUsed(
          canonicalTable: _purchaseTables.first,
          selectedTable: table,
          selectedIndex: index,
        );
        return rows
            .whereType<Map<String, dynamic>>()
            .map(AiCreditPurchase.fromJson)
            .toList(growable: false);
      } on Object catch (error) {
        lastError = error;
      }
    }
    throw MonetizationBackendException(
      'Purchase history could not be loaded from Supabase: ${lastError ?? 'unknown error'}',
    );
  }

  @override
  Future<AiCreditWallet?> consumeCredits({
    required int amount,
    required String reason,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final sb.SupabaseClient? client = _client;
    if (client == null) {
      throw const MonetizationBackendException(
        'Supabase monetization backend is unavailable.',
      );
    }

    final dynamic result = await client.rpc<dynamic>(
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
      throw const MonetizationBackendException(
        'Supabase consume credits returned an invalid payload.',
      );
    }

    return AiCreditWallet.fromJson(<String, dynamic>{
      'user_id': client.auth.currentUser?.id,
      'balance': row['balance'],
      'allowance_remaining': row['allowance_remaining'],
      'bonus_balance': row['bonus_balance'],
      'period_credits': row['period_credits'],
      'lifetime_earned': row['lifetime_earned'],
      'lifetime_spent': row['lifetime_spent'],
      'tier': row['tier'],
      'period_ends_at': row['period_ends_at'],
      'updated_at': row['updated_at'],
    });
  }

  void _logFallbackIfUsed({
    required String canonicalTable,
    required String selectedTable,
    required int selectedIndex,
  }) {
    if (selectedIndex <= 0) {
      return;
    }
    if (!_loggedFallbackTables.add(selectedTable)) {
      return;
    }
    Logger.warn(
      'Monetization fallback table in use: $selectedTable (canonical: $canonicalTable).',
    );
  }
}
