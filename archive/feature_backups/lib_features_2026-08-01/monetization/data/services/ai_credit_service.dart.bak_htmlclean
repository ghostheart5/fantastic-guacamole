import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/features/monetization/data/models/models.dart';
import 'package:fantastic_guacamole/features/monetization/data/repositories/ai_credit_repository.dart';
import 'package:fantastic_guacamole/features/monetization/data/services/analytics_events.dart';

class AiCreditService {
  const AiCreditService(this._repository);

  final AiCreditRepository _repository;

  Future<AiCreditWallet?> getWallet() => _repository.getWallet();

  Future<List<AiCreditTransaction>> getTransactions({int limit = 50}) {
    return _repository.getTransactions(limit: limit);
  }

  Future<List<AiCreditPurchase>> getPurchases({int limit = 50}) {
    return _repository.getPurchaseHistory(limit: limit);
  }

  Future<bool> canSpendCredits(int amount) async {
    final AiCreditWallet? wallet = await getWallet();
    return wallet != null && wallet.balance >= amount;
  }

  Future<AiCreditWallet?> spendCredits({
    required int amount,
    required String reason,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final bool allowed = await canSpendCredits(amount);
    if (!allowed) {
      AppAnalytics.track(MonetizationEvents.creditsInsufficient);
      return null;
    }

    final AiCreditWallet? wallet = await _repository.consumeCredits(
      amount: amount,
      reason: reason,
      metadata: metadata,
    );
    if (wallet != null) {
      AppAnalytics.track(MonetizationEvents.creditsSpent);
    }
    return wallet;
  }
}
