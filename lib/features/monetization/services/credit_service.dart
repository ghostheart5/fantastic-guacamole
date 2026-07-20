import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/features/monetization/models/ai_credit_transaction.dart';
import 'package:fantastic_guacamole/features/monetization/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/features/monetization/repositories/ai_credit_repository.dart';

class CreditBalanceCheck {
  const CreditBalanceCheck({required this.allowed, required this.wallet});

  final bool allowed;
  final AiCreditWallet wallet;
}

class CreditConsumeResult {
  const CreditConsumeResult({required this.allowed, required this.wallet});

  final bool allowed;
  final AiCreditWallet wallet;
}

class CreditService {
  const CreditService(this._repository);

  final AiCreditRepository _repository;

  Future<AiCreditWallet> loadWallet() {
    return _repository.getWallet();
  }

  Future<List<AiCreditTransaction>> loadHistory() {
    return _repository.getCreditHistory();
  }

  Future<CreditBalanceCheck> checkBalance(int amount) async {
    final AiCreditWallet wallet = await _repository.getWallet();
    return CreditBalanceCheck(allowed: wallet.balance >= amount, wallet: wallet);
  }

  Future<CreditConsumeResult> consume({
    required int amount,
    required String reason,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final CreditBalanceCheck check = await checkBalance(amount);
    if (!check.allowed) {
      return CreditConsumeResult(allowed: false, wallet: check.wallet);
    }
    final AiCreditWallet wallet = await _repository.consumeCredits(
      amount: amount,
      reason: reason,
      metadata: metadata,
    );
    AppAnalytics.track(
      'credits_spent',
      params: <String, Object?>{
        'amount': amount,
        'remaining_balance': wallet.balance,
        'reason': reason,
      },
    );
    return CreditConsumeResult(allowed: true, wallet: wallet);
  }
}