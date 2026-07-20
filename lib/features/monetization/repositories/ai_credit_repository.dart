import 'package:fantastic_guacamole/features/monetization/data/monetization_remote_data_source.dart';
import 'package:fantastic_guacamole/features/monetization/models/ai_credit_transaction.dart';
import 'package:fantastic_guacamole/features/monetization/models/ai_credit_wallet.dart';

abstract class AiCreditRepository {
  Future<AiCreditWallet> getWallet();
  Future<List<AiCreditTransaction>> getCreditHistory();
  Future<AiCreditWallet> consumeCredits({
    required int amount,
    required String reason,
    Map<String, dynamic> metadata,
  });
}

class SupabaseAiCreditRepository implements AiCreditRepository {
  SupabaseAiCreditRepository(this._dataSource);

  final MonetizationRemoteDataSource _dataSource;

  @override
  Future<AiCreditWallet> consumeCredits({
    required int amount,
    required String reason,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) {
    return _dataSource.consumeCredits(
      amount: amount,
      reason: reason,
      metadata: metadata,
    );
  }

  @override
  Future<List<AiCreditTransaction>> getCreditHistory() {
    return _dataSource.fetchTransactions();
  }

  @override
  Future<AiCreditWallet> getWallet() {
    return _dataSource.fetchWallet();
  }
}