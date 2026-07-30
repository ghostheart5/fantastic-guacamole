import 'package:fantastic_guacamole/features/monetization/data/models/models.dart';
import 'package:fantastic_guacamole/features/monetization/data/repositories/ai_credit_repository.dart';
import 'package:fantastic_guacamole/features/monetization/data/repositories/entitlement_repository.dart';
import 'package:fantastic_guacamole/features/monetization/data/repositories/subscription_repository.dart';

class GetSubscriptionPlans {
  const GetSubscriptionPlans(this._repository);

  final SubscriptionRepository _repository;

  Future<List<SubscriptionPlan>> call() => _repository.getSubscriptionPlans();
}

class GetCurrentSubscription {
  const GetCurrentSubscription(this._repository);

  final SubscriptionRepository _repository;

  Future<UserSubscription?> call() => _repository.getCurrentSubscription();
}

class GetPremiumEntitlement {
  const GetPremiumEntitlement(this._repository);

  final EntitlementRepository _repository;

  Future<PremiumEntitlement> call() => _repository.getPremiumEntitlement();
}

class GetAiCreditWallet {
  const GetAiCreditWallet(this._repository);

  final AiCreditRepository _repository;

  Future<AiCreditWallet?> call() => _repository.getWallet();
}

class GetAiCreditTransactions {
  const GetAiCreditTransactions(this._repository);

  final AiCreditRepository _repository;

  Future<List<AiCreditTransaction>> call({int limit = 50}) {
    return _repository.getTransactions(limit: limit);
  }
}

class GetPurchaseHistory {
  const GetPurchaseHistory(this._repository);

  final AiCreditRepository _repository;

  Future<List<AiCreditPurchase>> call({int limit = 50}) {
    return _repository.getPurchaseHistory(limit: limit);
  }
}
