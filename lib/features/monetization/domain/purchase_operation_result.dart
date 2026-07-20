import 'package:fantastic_guacamole/features/monetization/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/features/monetization/models/subscription_status.dart';

class PurchaseOperationResult {
  const PurchaseOperationResult({
    required this.success,
    required this.message,
    required this.productId,
    this.restored = false,
    this.subscriptionStatus,
    this.wallet,
  });

  final bool success;
  final String message;
  final String productId;
  final bool restored;
  final SubscriptionStatus? subscriptionStatus;
  final AiCreditWallet? wallet;
}